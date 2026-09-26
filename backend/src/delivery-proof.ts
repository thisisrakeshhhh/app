import type { Context } from 'hono';
export function secureOtp():string {
 const a=new Uint32Array(1);let n:number;do{crypto.getRandomValues(a);n=a[0];}while(n>=4294800000);
 return (100000+n%900000).toString();
}
// The gateway contract is provider-neutral: an HTTPS POST must return
// { accepted: true, messageId: string }. HTTP 200 alone is not acknowledgement.
export async function requestOtp(c:Context<any>){
 const u=c.get('user');if(!['OWNER','DELIVERY_EXECUTIVE'].includes(u.role))return c.json({error:'Delivery or owner required'},403);
 const id=c.req.param('id');const db=c.env.DB as D1Database;
 const order=await db.prepare('SELECT * FROM orders WHERE id=? AND company_id=?').bind(id,u.company_id).first<any>();
 if(!order||(u.role==='DELIVERY_EXECUTIVE'&&order.delivery_employee_id!==u.sub))return c.json({error:'Order access denied'},403);
 if(order.status!=='OUT_FOR_DELIVERY')return c.json({error:'Order must be out for delivery'},400);
 const simulation=c.env.ENVIRONMENT==='development'&&c.env.SMS_MODE==='simulated';
 if(!simulation&&(!c.env.SMS_GATEWAY_URL||!c.env.SMS_GATEWAY_TOKEN))return c.json({success:false,deliveryStatus:'UNAVAILABLE',error:'Recipient messaging is not configured. Delivery cannot be confirmed.'},503);
 const old=await db.prepare('SELECT * FROM delivery_otps WHERE order_id=? AND company_id=?').bind(id,u.company_id).first<any>();
 const now=Date.now();
 if(old&&['SENT','SIMULATED'].includes(old.send_status)&&old.expires_at>now&&old.attempt_count<old.max_attempts&&!old.is_used){
  return c.json({success:true,deliveryStatus:old.send_status,message:old.send_status==='SIMULATED'?'Development simulation: no SMS sent':'Recipient message previously acknowledged',expiresAt:old.expires_at,...(simulation?{debugOtp:old.otp_code}:{})});
 }
 if(old&&now-old.created_at<60000)return c.json({error:'Wait before requesting another OTP'},429);
 const otp=secureOtp(),expiresAt=now+5*60000;
 // Conditional UPSERT prevents simultaneous resend requests replacing each other.
 const claimed=await db.prepare(`INSERT INTO delivery_otps(order_id,company_id,otp_code,expires_at,created_at,send_status) VALUES(?,?,?,?,?,'SENDING') ON CONFLICT(order_id) DO UPDATE SET otp_code=excluded.otp_code,expires_at=excluded.expires_at,created_at=excluded.created_at,attempt_count=0,is_used=0,send_status='SENDING',provider_id=NULL WHERE delivery_otps.created_at<=?`).bind(id,u.company_id,otp,expiresAt,now,now-60000).run();
 if(!claimed.meta.changes)return c.json({error:'OTP request already in progress'},429);
 let providerId:string|null=null;
 if(!simulation){
  try{
   const url=new URL(c.env.SMS_GATEWAY_URL);if(url.protocol!=='https:')throw new Error('HTTPS required');
   const retailer=await db.prepare('SELECT contact_number FROM retailers WHERE id=? AND company_id=?').bind(order.retailer_id,u.company_id).first<any>();
   const response=await fetch(url,{method:'POST',headers:{Authorization:`Bearer ${c.env.SMS_GATEWAY_TOKEN}`,'Content-Type':'application/json'},body:JSON.stringify({to:retailer.contact_number,template:'routeflow_delivery_otp',otp,orderId:id,idempotencyKey:`otp_${id}_${now}`}),signal:AbortSignal.timeout(10000)});
   const data=await response.json() as {accepted?:boolean;messageId?:string};
   if(!response.ok||data.accepted!==true||!data.messageId)throw new Error('No provider acknowledgement');providerId=data.messageId;
  }catch{
   await db.prepare("UPDATE delivery_otps SET send_status='FAILED' WHERE order_id=? AND otp_code=?").bind(id,otp).run();
   return c.json({success:false,deliveryStatus:'UNAVAILABLE',error:'Recipient message was not acknowledged. Retry later.'},503);
  }
 }
 const status=simulation?'SIMULATED':'SENT';
 await db.prepare('UPDATE delivery_otps SET send_status=?,provider_id=? WHERE order_id=? AND otp_code=?').bind(status,providerId,id,otp).run();
 return c.json({success:true,deliveryStatus:status,message:simulation?'Development simulation: no SMS sent':'Recipient message acknowledged by provider',expiresAt,...(simulation?{debugOtp:otp}:{})});
}
