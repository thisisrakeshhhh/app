import { Hono, type MiddlewareHandler } from 'hono';
import { audit, commit, replay, retailerAllowed, type CycleEnv } from './daily-cycle';
type Row=Record<string,any>;
const time=(x:unknown):x is number=>Number.isSafeInteger(x)&&(x as number)>0&&(x as number)<=Date.now()+60000;
const coordinates=(b:Row)=> (b.latitude==null&&b.longitude==null)||(Number.isFinite(b.latitude)&&Math.abs(b.latitude)<=90&&Number.isFinite(b.longitude)&&Math.abs(b.longitude)<=180);
export function fieldCycle(auth:MiddlewareHandler<CycleEnv>){
 const app=new Hono<CycleEnv>();app.use('*',auth);
 app.post('/visits',async c=>{
  const u=c.get('user'),b=await c.req.json<Row>();
  if(!['OWNER','SALESPERSON'].includes(u.role)||!await retailerAllowed(c.env.DB,u,b.retailerId))return c.json({error:'Visit access denied'},403);
  b.idempotencyKey=b.idempotencyKey||`visit_${b.id}`;
  const prior=await replay(c,'VISIT_START',b);if(prior)return prior;
  if(typeof b.id!=='string'||!time(b.checkInTime)||!coordinates(b)||!['ACTIVE','COMPLETED'].includes(b.status)|| (b.status==='COMPLETED'&&(!time(b.checkOutTime)||b.checkOutTime<b.checkInTime)))return c.json({error:'Invalid visit event'},400);
  return commit(c,'VISIT_START',b,[c.env.DB.prepare('INSERT INTO visits(id,company_id,retailer_id,employee_id,check_in_time,check_out_time,latitude,longitude,accuracy,duration_seconds,status,no_order_reason,notes,idempotency_key,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)').bind(b.id,u.company_id,b.retailerId,u.sub,b.checkInTime,b.checkOutTime??null,b.latitude??null,b.longitude??null,b.accuracy??null,b.checkOutTime?Math.floor((b.checkOutTime-b.checkInTime)/1000):0,b.status,b.noOrderReason??null,b.notes??null,b.idempotencyKey,Date.now()),audit(c,'VISIT_STARTED',b.id,b)],{success:true,visitId:b.id});
 });
 app.put('/visits/:id/checkout',async c=>{
  const u=c.get('user'),id=c.req.param('id'),b=await c.req.json<Row>();
  const v=await c.env.DB.prepare('SELECT * FROM visits WHERE id=? AND company_id=? AND employee_id=?').bind(id,u.company_id,u.sub).first<Row>();
  if(!v||!['OWNER','SALESPERSON'].includes(u.role)||!await retailerAllowed(c.env.DB,u,v.retailer_id))return c.json({error:'Visit access denied'},403);
  b.idempotencyKey=b.idempotencyKey||`checkout_${id}`;const prior=await replay(c,`VISIT_END_${id}`,b);if(prior)return prior;
  if(!time(b.checkOutTime)||b.checkOutTime<v.check_in_time||v.status!=='ACTIVE')return c.json({error:'Invalid checkout event'},409);
  return commit(c,`VISIT_END_${id}`,b,[c.env.DB.prepare("UPDATE visits SET check_out_time=?,duration_seconds=?,status='COMPLETED',no_order_reason=?,notes=? WHERE id=?").bind(b.checkOutTime,Math.floor((b.checkOutTime-v.check_in_time)/1000),b.noOrderReason??null,b.notes??null,id),audit(c,'VISIT_COMPLETED',id,b)],{success:true});
 });
 app.get('/visits',async c=>{
  const u=c.get('user');if(!['OWNER','SALESPERSON'].includes(u.role))return c.json({error:'Visit access denied'},403);
  return c.json((await c.env.DB.prepare(`SELECT id,retailer_id AS retailerId,employee_id AS employeeId,check_in_time AS checkInTime,check_out_time AS checkOutTime,latitude,longitude,accuracy,duration_seconds AS durationSeconds,status,no_order_reason AS noOrderReason,notes FROM visits WHERE company_id=? ${u.role==='OWNER'?'':'AND employee_id=?'} ORDER BY check_in_time DESC LIMIT 200`).bind(u.company_id,...(u.role==='OWNER'?[]:[u.sub])).all()).results);
 });
 app.post('/stock-checks',async c=>{
  const u=c.get('user'),b=await c.req.json<Row>();
  if(!['OWNER','SALESPERSON'].includes(u.role)||!await retailerAllowed(c.env.DB,u,b.retailerId))return c.json({error:'Stock check access denied'},403);
  const p=await c.env.DB.prepare('SELECT 1 FROM products WHERE id=? AND company_id=?').bind(b.productId,u.company_id).first();
  if(!p||!Number.isSafeInteger(b.quantity)||b.quantity<0||b.quantity>100000)return c.json({error:'Invalid stock check'},400);
  const prior=await replay(c,'STOCK_CHECK',b);if(prior)return prior;
  const id=b.id||crypto.randomUUID();return commit(c,'STOCK_CHECK',b,[c.env.DB.prepare('INSERT INTO stock_checks VALUES(?,?,?,?,?,?,?)').bind(id,u.company_id,b.retailerId,u.sub,b.productId,b.quantity,Date.now()),audit(c,'STOCK_CHECK',id,b)],{success:true,stockCheckId:id});
 });
 app.get('/stock-checks/:retailerId',async c=>{
  const u=c.get('user'),id=c.req.param('retailerId');if(!['OWNER','SALESPERSON'].includes(u.role)||!await retailerAllowed(c.env.DB,u,id))return c.json({error:'Stock check access denied'},403);
  return c.json((await c.env.DB.prepare('SELECT sc.id,sc.product_id AS productId,p.name AS productName,sc.quantity,sc.created_at AS createdAt FROM stock_checks sc JOIN products p ON p.id=sc.product_id WHERE sc.company_id=? AND sc.retailer_id=? ORDER BY sc.created_at DESC LIMIT 100').bind(u.company_id,id).all()).results);
 });
 app.post('/shifts/start',async c=>{
  const u=c.get('user'),b=await c.req.json<Row>();if(!['SALESPERSON','DELIVERY_EXECUTIVE'].includes(u.role))return c.json({error:'Field employee required'},403);
  const prior=await replay(c,'SHIFT_START',b);if(prior)return prior;
  if(typeof b.shiftId!=='string'||!time(b.startTime)||!coordinates(b))return c.json({error:'Invalid shift start'},400);
  return commit(c,'SHIFT_START',b,[c.env.DB.prepare("INSERT INTO shifts(id,company_id,user_id,status,start_time,start_latitude,start_longitude,created_at) VALUES(?,?,?,'ON_SHIFT',?,?,?,?)").bind(b.shiftId,u.company_id,u.sub,b.startTime,b.latitude??null,b.longitude??null,Date.now()),audit(c,'SHIFT_STARTED',b.shiftId,b)],{success:true,shift:{id:b.shiftId,status:'ON_SHIFT',startTime:b.startTime}});
 });
 app.get('/shifts/current',async c=>{
  const u=c.get('user');if(!['SALESPERSON','DELIVERY_EXECUTIVE'].includes(u.role))return c.json({error:'Field employee required'},403);
  return c.json({success:true,shift:await c.env.DB.prepare("SELECT id,status,start_time AS startTime,end_time AS endTime FROM shifts WHERE company_id=? AND user_id=? AND status IN ('ON_SHIFT','ON_BREAK') ORDER BY start_time DESC LIMIT 1").bind(u.company_id,u.sub).first()});
 });
 for(const action of ['end','pause','resume'])app.post(`/shifts/${action}`,async c=>{
  const u=c.get('user'),b=await c.req.json<Row>();
  if(!['SALESPERSON','DELIVERY_EXECUTIVE'].includes(u.role))return c.json({error:'Field employee required'},403);
  const s=await c.env.DB.prepare('SELECT * FROM shifts WHERE id=? AND company_id=? AND user_id=?').bind(b.shiftId,u.company_id,u.sub).first<Row>();if(!s)return c.json({error:'Shift access denied'},403);
  const op=`SHIFT_${action}_${s.id}`,prior=await replay(c,op,b);if(prior)return prior;
  const at=b.endTime??b.timestamp;if(!time(at)||at<s.start_time||!coordinates(b))return c.json({error:'Invalid shift event time'},400);
  const status=action==='end'?'OFF_SHIFT':action==='pause'?'ON_BREAK':'ON_SHIFT';
  if(s.status==='OFF_SHIFT'||(action==='pause'&&s.status!=='ON_SHIFT')||(action==='resume'&&s.status!=='ON_BREAK'))return c.json({error:'Invalid shift transition'},409);
  const statements=[c.env.DB.prepare('UPDATE shifts SET status=?,end_time=?,end_latitude=?,end_longitude=? WHERE id=?').bind(status,action==='end'?at:null,b.latitude??null,b.longitude??null,s.id),audit(c,op,s.id,b)];
  if(action==='pause')statements.push(c.env.DB.prepare('INSERT INTO shift_breaks VALUES(?,?,?,NULL)').bind(b.idempotencyKey,s.id,at));
  else statements.push(c.env.DB.prepare('UPDATE shift_breaks SET end_time=? WHERE shift_id=? AND end_time IS NULL').bind(at,s.id));
  // Discard neither old points nor business records. Reject events preceding already accepted points.
  const future=await c.env.DB.prepare('SELECT 1 FROM shift_locations WHERE shift_id=? AND timestamp>? LIMIT 1').bind(s.id,at).first();
  if(action==='end'&&future)return c.json({error:'End time precedes recorded locations; review shift'},409);
  return commit(c,op,b,statements,{success:true,shift:{id:s.id,status,startTime:s.start_time,endTime:action==='end'?at:null}});
 });
 app.post('/shifts/locations',async c=>{
  const u=c.get('user'),b=await c.req.json<Row>();if(!['SALESPERSON','DELIVERY_EXECUTIVE'].includes(u.role))return c.json({error:'Field employee required'},403);
  const s=await c.env.DB.prepare('SELECT * FROM shifts WHERE id=? AND company_id=? AND user_id=?').bind(b.shiftId,u.company_id,u.sub).first<Row>();if(!s)return c.json({error:'Shift access denied'},403);
  if(!Array.isArray(b.points)||!b.points.length||b.points.length>100)return c.json({error:'1–100 points required'},400);
  const breaks=(await c.env.DB.prepare('SELECT * FROM shift_breaks WHERE shift_id=?').bind(s.id).all<Row>()).results;
  const statements=[];
  for(const p of b.points){
   if(typeof p.id!=='string'||!time(p.timestamp)||p.timestamp<s.start_time||(s.end_time&&p.timestamp>s.end_time)||!coordinates(p)||p.latitude==null||!Number.isFinite(p.accuracy)||p.accuracy<0||breaks.some(x=>p.timestamp>=x.start_time&&(!x.end_time||p.timestamp<x.end_time)))return c.json({error:'Point is invalid or outside recorded working time'},400);
   const existing=await c.env.DB.prepare('SELECT * FROM shift_locations WHERE id=?').bind(p.id).first<Row>();
   if(existing&&(existing.shift_id!==s.id||existing.user_id!==u.sub||existing.company_id!==u.company_id||existing.timestamp!==p.timestamp||existing.latitude!==p.latitude||existing.longitude!==p.longitude||existing.accuracy!==p.accuracy))return c.json({error:'Location event ID conflict'},409);
   statements.push(c.env.DB.prepare('INSERT OR IGNORE INTO shift_locations VALUES(?,?,?,?,?,?,?,?)').bind(p.id,s.id,u.company_id,u.sub,p.latitude,p.longitude,p.accuracy,p.timestamp));
  }
  await c.env.DB.batch(statements);return c.json({success:true,count:b.points.length});
 });
 return app;
}
