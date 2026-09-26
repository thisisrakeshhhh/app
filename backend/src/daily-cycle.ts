import { Hono, type Context, type MiddlewareHandler } from 'hono';

export type Actor = { sub: string; company_id: string; role: string; sid: string; name: string };
export type CycleEnv = { Bindings: { DB: D1Database }; Variables: { user: Actor } };
type Ctx = Context<CycleEnv>;
type Row = Record<string, any>;
const fieldRoles = ['OWNER', 'SALESPERSON', 'DELIVERY_EXECUTIVE'];
export const money = (n: unknown, zero = false): n is number => Number.isSafeInteger(n) && (n as number) >= (zero ? 0 : 1) && (n as number) <= 1_000_000_000;
const quantity = (n: unknown): n is number => Number.isSafeInteger(n) && (n as number) >= 0 && (n as number) <= 100000;
const bad = (c: Ctx, error: string, status: 400 | 403 | 404 | 409 = 400) => c.json({ error }, status);
export async function retailerAllowed(db: D1Database, u: Actor, id: string): Promise<boolean> {
 if (!fieldRoles.includes(u.role)) return false;
 const r = await db.prepare('SELECT beat_id FROM retailers WHERE id = ? AND company_id = ?').bind(id, u.company_id).first<{ beat_id: string }>();
 if (!r) return false;
 if (u.role === 'OWNER') return true;
 if (u.role === 'SALESPERSON') return !!await db.prepare('SELECT 1 FROM user_beat_assignments WHERE user_id = ? AND company_id = ? AND beat_id = ?').bind(u.sub, u.company_id, r.beat_id).first();
 return !!await db.prepare("SELECT 1 FROM orders WHERE retailer_id = ? AND company_id = ? AND delivery_employee_id = ? AND status IN ('OUT_FOR_DELIVERY','DELIVERED')").bind(id, u.company_id, u.sub).first();
}
export const audit = (c: Ctx, action: string, id: string, details: unknown) => c.env.DB.prepare(
 'INSERT INTO audit_logs (id,company_id,user_id,action,entity_id,details,timestamp) VALUES (?,?,?,?,?,?,?)'
).bind(crypto.randomUUID(), c.get('user').company_id, c.get('user').sub, action, id, JSON.stringify(details), Date.now());
async function hash(body: unknown) {
 const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(JSON.stringify(body)));
 return Array.from(new Uint8Array(bytes), b => b.toString(16).padStart(2, '0')).join('');
}
// Receipt insertion shares the transaction with the mutation. A racing duplicate
// aborts its entire batch, then reads the winner's bound response.
export async function replay(c: Ctx, operation: string, body: Row) {
 if (typeof body.idempotencyKey !== 'string' || body.idempotencyKey.length < 8 || body.idempotencyKey.length > 200) return bad(c, 'Stable idempotencyKey required');
 const prior = await c.env.DB.prepare('SELECT * FROM operation_receipts WHERE id = ?').bind(body.idempotencyKey).first<Row>();
 if (!prior) return null;
 const u = c.get('user');
 if (prior.actor_id !== u.sub || prior.company_id !== u.company_id || prior.operation !== operation || prior.request_hash !== await hash(body)) return bad(c, 'Idempotency key belongs to a different request', 409);
 return c.json({ ...JSON.parse(prior.response), idempotent: true });
}
export async function commit(c: Ctx, operation: string, body: Row, statements: D1PreparedStatement[], response: Row) {
 const u = c.get('user');
 statements.push(c.env.DB.prepare('INSERT INTO operation_receipts VALUES (?,?,?,?,?,?,?)').bind(body.idempotencyKey, u.company_id, u.sub, operation, await hash(body), JSON.stringify(response), Date.now()));
 try { await c.env.DB.batch(statements); return c.json(response); }
 catch (e) {
  const prior = await replay(c, operation, body); if (prior) return prior;
  const message = e instanceof Error ? e.message : '';
  const known = ['Invoice allocation exceeds unpaid balance','Collection transition already applied or invalid','Return exceeds remaining delivered quantity','Return transition already applied or invalid','Pending handover exists','Handover exceeds cash custody','Handover already acknowledged'];
  return bad(c, known.find(x => message.includes(x)) || 'Operation conflict; refresh and review before retrying', 409);
 }
}
async function collection(c: Ctx, id: string) {
 const u = c.get('user');
 const row = await c.env.DB.prepare('SELECT * FROM collections WHERE id = ? AND company_id = ?').bind(id, u.company_id).first<Row>();
 return row && await retailerAllowed(c.env.DB, u, row.retailer_id) ? row : null;
}
async function allocations(c: Ctx, retailerId: string, amount: number, input: unknown): Promise<{ items: Array<{ invoiceId: string; amountPaise: number }>; error?: string }> {
 if (input === undefined || input === null) {
  const rows = await c.env.DB.prepare('SELECT id,total_amount_paise-paid_paise-credited_paise AS due FROM invoices WHERE company_id=? AND retailer_id=? AND total_amount_paise>paid_paise+credited_paise ORDER BY created_at,id').bind(c.get('user').company_id, retailerId).all<{ id: string; due: number }>();
  let left = amount;
  return { items: rows.results.flatMap(r => { const take = Math.min(left, r.due); left -= take; return take ? [{ invoiceId: r.id, amountPaise: take }] : []; }) };
 }
 if (!Array.isArray(input) || input.length > 100) return { items: [], error: 'Invalid invoice allocations' };
 const seen = new Set(); let sum = 0;
 for (const a of input) {
  if (!a || typeof a.invoiceId !== 'string' || seen.has(a.invoiceId) || !money(a.amountPaise)) return { items: [], error: 'Invalid or duplicate allocation' };
  seen.add(a.invoiceId); sum += a.amountPaise;
 }
 return sum <= amount ? { items: input } : { items: [], error: 'Allocations exceed payment amount' };
}
function settlement(c: Ctx, row: Row, items: Array<{ invoiceId: string; amountPaise: number }>, status: string, reason: string): D1PreparedStatement[] {
 const u = c.get('user'); const db = c.env.DB;
 const allocated = items.reduce((s, a) => s + a.amountPaise, 0);
 const statements = [db.prepare('UPDATE collections SET status=?,unapplied_paise=?,reviewed_by=?,review_reason=?,updated_at=? WHERE id=?').bind(status, row.amount_paise - allocated, u.sub, reason, Date.now(), row.id)];
 for (const a of items) {
  statements.push(db.prepare('INSERT INTO collection_allocations VALUES (?,?,?)').bind(row.id, a.invoiceId, a.amountPaise));
  statements.push(db.prepare("UPDATE invoices SET paid_paise=paid_paise+?,status=CASE WHEN paid_paise+?+credited_paise=total_amount_paise THEN 'PAID' ELSE 'PARTIAL' END WHERE id=?").bind(a.amountPaise, a.amountPaise, a.invoiceId));
 }
 statements.push(db.prepare('UPDATE retailers SET outstanding_amount_paise=outstanding_amount_paise-? WHERE id=? AND company_id=?').bind(row.amount_paise, row.retailer_id, u.company_id));
 statements.push(db.prepare(`INSERT INTO payment_ledger (id,collection_id,company_id,retailer_id,entry_type,amount_paise,balance_after_paise,payment_method,collected_by,created_at,idempotency_key)
 SELECT ?,?,?,?,?,?,outstanding_amount_paise,?,?,?,? FROM retailers WHERE id=? AND company_id=?`).bind(crypto.randomUUID(), row.id, u.company_id, row.retailer_id, `${row.payment_method}_PAYMENT`, row.amount_paise, row.payment_method, row.collected_by, Date.now(), `settle_${row.id}`, row.retailer_id, u.company_id));
 statements.push(audit(c, 'COLLECTION_SETTLED', row.id, { status, reason, allocations: items, unappliedPaise: row.amount_paise - allocated }));
 return statements;
}
async function cash(db: D1Database, company: string, employee: string) {
 const r = await db.prepare(`SELECT COALESCE(SUM(CASE WHEN entry_type='CASH_REVERSAL' THEN -amount_paise ELSE amount_paise END),0) AS total FROM payment_ledger WHERE company_id=? AND collected_by=? AND entry_type IN ('CASH_PAYMENT','CASH_REVERSAL')`).bind(company, employee).first<{ total: number }>();
 const h = await db.prepare("SELECT COALESCE(SUM(received_amount_paise),0) AS total FROM cash_handovers WHERE company_id=? AND user_id=? AND status='ACCEPTED'").bind(company, employee).first<{ total: number }>();
 return { cashHeldPaise: (r?.total || 0) - (h?.total || 0), totalCollectedPaise: r?.total || 0, totalSettledPaise: h?.total || 0 };
}

export function dailyCycle(auth: MiddlewareHandler<CycleEnv>) {
 const app = new Hono<CycleEnv>(); app.use('*', auth);
 app.get('/invoices', async c => {
  const retailerId = c.req.query('retailerId') || '';
  if (!await retailerAllowed(c.env.DB, c.get('user'), retailerId)) return bad(c, 'Retailer access denied', 403);
  return c.json({ invoices: (await c.env.DB.prepare('SELECT *,total_amount_paise-paid_paise-credited_paise AS outstanding_paise FROM invoices WHERE company_id=? AND retailer_id=? ORDER BY created_at').bind(c.get('user').company_id, retailerId).all()).results });
 });
 app.post('/collections', async c => {
  const u = c.get('user'); const b = await c.req.json<Row>();
  if (!await retailerAllowed(c.env.DB, u, b.retailerId)) return bad(c, 'Collection access denied', 403);
  const prior = await replay(c, 'COLLECT', b); if (prior) return prior;
  if (!money(b.amountPaise) || !['CASH','UPI','CHEQUE','BANK'].includes(b.paymentMethod)) return bad(c, 'Invalid payment amount or method');
  if (b.paymentMethod !== 'CASH' && (typeof b.reference !== 'string' || !b.reference.trim())) return bad(c, 'Payment reference required; verification is separate');
  const alloc = await allocations(c, b.retailerId, b.amountPaise, b.allocations); if (alloc.error) return bad(c, alloc.error);
  const id = `col_${crypto.randomUUID()}`; const receiptId = `REC-${crypto.randomUUID()}`;
  const row = { id, amount_paise: b.amountPaise, retailer_id: b.retailerId, payment_method: b.paymentMethod, collected_by: u.sub };
  const statements = [c.env.DB.prepare(`INSERT INTO collections (id,company_id,retailer_id,collected_by,amount_paise,payment_method,receipt_id,notes,idempotency_key,created_at,status,reference,unapplied_paise,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,'ENTERED',?,?,?)`).bind(id,u.company_id,b.retailerId,u.sub,b.amountPaise,b.paymentMethod,receiptId,b.notes || null,b.idempotencyKey,Date.now(),b.reference || null,b.amountPaise,Date.now()), audit(c, 'COLLECTION_ENTERED', id, { method: b.paymentMethod, amount: b.amountPaise })];
  if (b.paymentMethod === 'CASH') statements.push(...settlement(c,row,alloc.items,'SETTLED','Cash received by authorized employee'));
  // Pending non-cash allocations are selected by the owner at clearance; no invoice is prematurely changed.
  const current = await c.env.DB.prepare('SELECT outstanding_amount_paise FROM retailers WHERE id=?').bind(b.retailerId).first<Row>();
  return commit(c,'COLLECT',b,statements,{success:true,collectionId:id,receiptId,status:b.paymentMethod === 'CASH' ? 'SETTLED' : 'ENTERED',unappliedPaise:b.paymentMethod === 'CASH' ? b.amountPaise-alloc.items.reduce((s,a)=>s+a.amountPaise,0) : b.amountPaise,balanceAfterPaise:current!.outstanding_amount_paise-(b.paymentMethod === 'CASH' ? b.amountPaise : 0)});
 });
 app.get('/collections', async c => {
  const u = c.get('user'); if (!fieldRoles.includes(u.role)) return bad(c,'Collection access denied',403);
  const retailerId = c.req.query('retailerId'); if (retailerId && !await retailerAllowed(c.env.DB,u,retailerId)) return bad(c,'Retailer access denied',403);
  const rows = await c.env.DB.prepare(`SELECT c.*,r.name AS retailer_name,u.full_name AS collected_by_name FROM collections c JOIN retailers r ON r.id=c.retailer_id JOIN users u ON u.id=c.collected_by WHERE c.company_id=? ${u.role === 'OWNER' ? '' : 'AND c.collected_by=?'} ${retailerId ? 'AND c.retailer_id=?' : ''} ORDER BY c.created_at DESC LIMIT 200`).bind(u.company_id,...(u.role === 'OWNER' ? [] : [u.sub]),...(retailerId ? [retailerId] : [])).all();
  return c.json({collections:rows.results});
 });
 app.post('/collections/:id/review', async c => {
  const u = c.get('user'); if (u.role !== 'OWNER') return bad(c,'Owner required',403);
  const row = await collection(c,c.req.param('id')); if (!row) return bad(c,'Collection not found',404);
  const b = await c.req.json<Row>(); const prior = await replay(c,`REVIEW_${row.id}`,b); if (prior) return prior;
  if (!['VERIFY','CLEAR','REJECT','REVERSE'].includes(b.action) || !b.reason?.trim()) return bad(c,'Action and reason required');
  const statements: D1PreparedStatement[] = []; let status: string;
  if (b.action === 'REVERSE') {
   if (!['SETTLED','VERIFIED','CLEARED','LEGACY_REVIEW'].includes(row.status)) return bad(c,'Only settled payments can be reversed',409);
   // Cash already transferred must be physically returned before reversal; otherwise custody would be fabricated.
   if (row.payment_method === 'CASH') {
    const held = await cash(c.env.DB,u.company_id,row.collected_by);
    const open = await c.env.DB.prepare("SELECT 1 FROM cash_handovers WHERE company_id=? AND user_id=? AND status='PENDING'").bind(u.company_id,row.collected_by).first();
    if (open || held.cashHeldPaise < row.amount_paise) return bad(c,'Resolve pending handover or return cash custody before reversing',409);
   }
   status='REVERSED';
   statements.push(c.env.DB.prepare("UPDATE collections SET status='REVERSED',reviewed_by=?,review_reason=?,updated_at=? WHERE id=?").bind(u.sub,b.reason,Date.now(),row.id));
   statements.push(c.env.DB.prepare('UPDATE retailers SET outstanding_amount_paise=outstanding_amount_paise+? WHERE id=? AND company_id=?').bind(row.amount_paise,row.retailer_id,u.company_id));
   statements.push(c.env.DB.prepare(`UPDATE invoices SET paid_paise=paid_paise-(SELECT amount_paise FROM collection_allocations WHERE collection_id=? AND invoice_id=invoices.id),status='ISSUED' WHERE id IN (SELECT invoice_id FROM collection_allocations WHERE collection_id=?)`).bind(row.id,row.id));
   statements.push(c.env.DB.prepare(`INSERT INTO payment_ledger(id,collection_id,company_id,retailer_id,entry_type,amount_paise,balance_after_paise,payment_method,collected_by,created_at,idempotency_key) SELECT ?,?,?,?,?,?,outstanding_amount_paise,?,?,?,? FROM retailers WHERE id=?`).bind(crypto.randomUUID(),row.id,u.company_id,row.retailer_id,`${row.payment_method}_REVERSAL`,row.amount_paise,row.payment_method,row.collected_by,Date.now(),`reverse_${row.id}`,row.retailer_id));
  } else {
   if (row.status !== 'ENTERED') return bad(c,'Payment is no longer pending verification',409);
   if (b.action === 'REJECT') {
    status='REJECTED'; statements.push(c.env.DB.prepare("UPDATE collections SET status='REJECTED',reviewed_by=?,review_reason=?,updated_at=? WHERE id=?").bind(u.sub,b.reason,Date.now(),row.id));
   } else {
    if ((row.payment_method === 'CHEQUE') !== (b.action === 'CLEAR')) return bad(c,'Cheques require clearance; bank/UPI require verification');
    const alloc = await allocations(c,row.retailer_id,row.amount_paise,b.allocations); if (alloc.error) return bad(c,alloc.error);
    status=b.action==='CLEAR'?'CLEARED':'VERIFIED'; statements.push(...settlement(c,row,alloc.items,status,b.reason));
   }
  }
  statements.push(audit(c,`COLLECTION_${b.action}`,row.id,{reason:b.reason}));
  return commit(c,`REVIEW_${row.id}`,b,statements,{success:true,status});
 });
 app.get('/handovers/summary', async c => {
  const u=c.get('user'); if (!fieldRoles.includes(u.role)) return bad(c,'Cash custody access denied',403);
  const rows=await c.env.DB.prepare('SELECT * FROM cash_handovers WHERE company_id=? AND user_id=? ORDER BY submitted_at DESC LIMIT 100').bind(u.company_id,u.sub).all<Row>();
  return c.json({...await cash(c.env.DB,u.company_id,u.sub),pendingHandover:rows.results.find(h=>h.status==='PENDING')||null,recentHandovers:rows.results});
 });
 app.post('/handovers/request', async c => {
  const u=c.get('user'); if (!['SALESPERSON','DELIVERY_EXECUTIVE'].includes(u.role)) return bad(c,'Field employee required',403);
  const b=await c.req.json<Row>(); const prior=await replay(c,'HANDOVER',b); if(prior)return prior;
  if(!money(b.amountPaise))return bad(c,'Invalid cash amount');
  const held=await cash(c.env.DB,u.company_id,u.sub); if(b.amountPaise>held.cashHeldPaise)return bad(c,'Amount exceeds cash held');
  const pending=await c.env.DB.prepare("SELECT 1 FROM cash_handovers WHERE company_id=? AND user_id=? AND status='PENDING'").bind(u.company_id,u.sub).first();
  if(pending)return bad(c,'Pending handover exists');
  const id=`hnd_${crypto.randomUUID()}`;
  return commit(c,'HANDOVER',b,[c.env.DB.prepare("INSERT INTO cash_handovers(id,company_id,user_id,amount_paise,status,submitted_at,notes,expected_amount_paise) VALUES(?,?,?,?,'PENDING',?,?,?)").bind(id,u.company_id,u.sub,b.amountPaise,Date.now(),b.notes||null,held.cashHeldPaise),audit(c,'HANDOVER_REQUESTED',id,b)],{success:true,handoverId:id,status:'PENDING',amountPaise:b.amountPaise});
 });
 app.get('/owner/handovers', async c => {
  if(c.get('user').role!=='OWNER')return bad(c,'Owner required',403);
  return c.json({handovers:(await c.env.DB.prepare('SELECT h.*,u.full_name AS employee_name,u.role AS employee_role FROM cash_handovers h JOIN users u ON u.id=h.user_id WHERE h.company_id=? ORDER BY h.submitted_at DESC LIMIT 200').bind(c.get('user').company_id).all()).results});
 });
 app.post('/owner/handovers/:id/acknowledge', async c => {
  const u=c.get('user'); if(u.role!=='OWNER')return bad(c,'Owner required',403);
  const row=await c.env.DB.prepare('SELECT * FROM cash_handovers WHERE id=? AND company_id=?').bind(c.req.param('id'),u.company_id).first<Row>(); if(!row)return bad(c,'Handover not found',404);
  const b=await c.req.json<Row>(); const prior=await replay(c,`ACK_${row.id}`,b);if(prior)return prior;
  if(row.user_id===u.sub)return bad(c,'A different employee must acknowledge physical cash',403);
  if(!['ACCEPT','REJECT'].includes(b.action)||row.status!=='PENDING')return bad(c,'Invalid handover transition',409);
  const received=b.action==='ACCEPT'?(b.receivedAmountPaise??row.amount_paise):0;
  if(!money(received,true)||received>row.amount_paise)return bad(c,'Accepted amount must be between zero and declared amount');
  const discrepancy=b.action==='ACCEPT'?received-row.amount_paise:0;
  if((discrepancy!==0||b.action==='REJECT')&&!b.notes?.trim())return bad(c,'Discrepancy or rejection requires notes');
  const status=b.action==='ACCEPT'?'ACCEPTED':'REJECTED';
  return commit(c,`ACK_${row.id}`,b,[c.env.DB.prepare('UPDATE cash_handovers SET status=?,acknowledged_at=?,acknowledged_by=?,received_amount_paise=?,discrepancy_paise=?,resolution_notes=? WHERE id=?').bind(status,Date.now(),u.sub,received,discrepancy,b.notes||null,row.id),audit(c,`HANDOVER_${status}`,row.id,b)],{success:true,status,receivedAmountPaise:received,discrepancyPaise:discrepancy});
 });
 app.get('/owner/closing',async c=>{
  const u=c.get('user');if(u.role!=='OWNER')return bad(c,'Owner required',403);
  const employees=await c.env.DB.prepare("SELECT id,full_name FROM users WHERE company_id=? AND role IN ('SALESPERSON','DELIVERY_EXECUTIVE')").bind(u.company_id).all<{id:string;full_name:string}>();
  const balances=[];for(const e of employees.results)balances.push({...e,...await cash(c.env.DB,u.company_id,e.id)});
  const closings=await c.env.DB.prepare('SELECT * FROM daily_closings WHERE company_id=? ORDER BY business_date DESC LIMIT 30').bind(u.company_id).all();
  return c.json({balances,closings:closings.results});
 });
 app.post('/owner/closing',async c=>{
  const u=c.get('user');if(u.role!=='OWNER')return bad(c,'Owner required',403);
  const b=await c.req.json<Row>();const prior=await replay(c,'CLOSE_DAY',b);if(prior)return prior;
  const today=new Date(Date.now()+19800000).toISOString().slice(0,10);
  if(b.businessDate!==today||!b.notes?.trim())return bad(c,'Closing requires today’s Jaipur business date and reconciliation notes');
  const id=crypto.randomUUID();
  // Snapshot is read inside the same batch as the close, including cash remaining
  // and unresolved requests. Closing is a checkpoint, never a balance reset.
  return commit(c,'CLOSE_DAY',b,[c.env.DB.prepare(`INSERT INTO daily_closings VALUES(?,?,?,?,?,json_object('cashCollected',COALESCE((SELECT SUM(CASE WHEN entry_type='CASH_REVERSAL' THEN -amount_paise ELSE amount_paise END) FROM payment_ledger WHERE company_id=? AND entry_type IN ('CASH_PAYMENT','CASH_REVERSAL')),0),'cashAccepted',COALESCE((SELECT SUM(received_amount_paise) FROM cash_handovers WHERE company_id=? AND status='ACCEPTED'),0),'pendingHandovers',(SELECT COUNT(*) FROM cash_handovers WHERE company_id=? AND status='PENDING')),?)`).bind(id,u.company_id,today,u.sub,Date.now(),u.company_id,u.company_id,u.company_id,b.notes),audit(c,'DAILY_CLOSING',id,b)],{success:true,id});
 });

 app.post('/returns',async c=>{
  const u=c.get('user');const b=await c.req.json<Row>();
  const order=await c.env.DB.prepare('SELECT * FROM orders WHERE id=? AND company_id=?').bind(b.orderId,u.company_id).first<Row>();
  if(!order||!await retailerAllowed(c.env.DB,u,order.retailer_id)||(u.role==='DELIVERY_EXECUTIVE'&&order.delivery_employee_id!==u.sub))return bad(c,'Return access denied',403);
  const prior=await replay(c,'RETURN_CREATE',b);if(prior)return prior;
  if(order.status!=='DELIVERED'||!Array.isArray(b.items)||!b.items.length||b.items.length>100)return bad(c,'Delivered order and return items required');
  const id=`ret_${crypto.randomUUID()}`;const seen=new Set();
  const statements=[c.env.DB.prepare("INSERT INTO return_requests(id,company_id,order_id,retailer_id,created_by,status,created_at,notes) VALUES(?,?,?,?,?,'REQUESTED',?,?)").bind(id,u.company_id,order.id,order.retailer_id,u.sub,Date.now(),b.notes||null)];
  for(const item of b.items){
   if(seen.has(item.productId)||!quantity(item.requestedQuantity)||!quantity(item.freeQuantity??0)||item.requestedQuantity+(item.freeQuantity??0)<=0)return bad(c,'Invalid or duplicate return quantities');seen.add(item.productId);
   const line=await c.env.DB.prepare('SELECT price_paise_at_time FROM order_items WHERE order_id=? AND product_id=?').bind(order.id,item.productId).first<Row>();if(!line)return bad(c,'Product was not delivered');
   statements.push(c.env.DB.prepare('INSERT INTO return_items(id,return_id,product_id,requested_quantity,unit_price_paise,free_quantity) VALUES(?,?,?,?,?,?)').bind(crypto.randomUUID(),id,item.productId,item.requestedQuantity,line.price_paise_at_time,item.freeQuantity??0));
  }
  statements.push(audit(c,'RETURN_REQUESTED',id,b));return commit(c,'RETURN_CREATE',b,statements,{success:true,returnId:id,status:'REQUESTED'});
 });
 app.get('/returns/pending',async c=>{
  const u=c.get('user');if(!['OWNER','WAREHOUSE_MANAGER'].includes(u.role))return bad(c,'Owner or warehouse required',403);
  const rows=await c.env.DB.prepare("SELECT r.*,t.name AS retailer_name FROM return_requests r JOIN retailers t ON t.id=r.retailer_id WHERE r.company_id=? AND r.status NOT IN ('REJECTED','CREDITED','APPROVED') ORDER BY r.created_at").bind(u.company_id).all<Row>();
  for(const r of rows.results)r.items=(await c.env.DB.prepare('SELECT ri.*,p.name AS product_name FROM return_items ri JOIN products p ON p.id=ri.product_id WHERE return_id=?').bind(r.id).all()).results;
  return c.json({returns:rows.results});
 });
 for(const step of ['authorize','receive','inspect','credit'] as const)app.post(`/returns/:id/${step}`,async c=>{
  const u=c.get('user');const ownerStep=step==='authorize'||step==='credit';
  if(ownerStep?u.role!=='OWNER':!['OWNER','WAREHOUSE_MANAGER'].includes(u.role))return bad(c,'Return action not permitted',403);
  const r=await c.env.DB.prepare('SELECT * FROM return_requests WHERE id=? AND company_id=?').bind(c.req.param('id'),u.company_id).first<Row>();if(!r)return bad(c,'Return not found',404);
  const b=await c.req.json<Row>();const op=`RETURN_${step}_${r.id}`;const prior=await replay(c,op,b);if(prior)return prior;
  const expected={authorize:'REQUESTED',receive:'AUTHORIZED',inspect:'RECEIVED',credit:'INSPECTED'}[step];if(r.status!==expected)return bad(c,`Return must be ${expected}`,409);
  const statements:D1PreparedStatement[]=[];let status='';let totalCreditNotePaise=0;
  if(step==='authorize'){
   if(!['APPROVE','REJECT'].includes(b.action)||!b.notes?.trim())return bad(c,'Authorization action and reason required');
   status=b.action==='APPROVE'?'AUTHORIZED':'REJECTED';statements.push(c.env.DB.prepare('UPDATE return_requests SET status=?,authorized_by=? WHERE id=?').bind(status,u.sub,r.id));
  }else if(step==='receive'){
   if(!b.notes?.trim())return bad(c,'Physical receipt confirmation required');status='RECEIVED';statements.push(c.env.DB.prepare("UPDATE return_requests SET status='RECEIVED',received_by=?,received_at=? WHERE id=?").bind(u.sub,Date.now(),r.id));
  }else if(step==='inspect'){
   const lines=(await c.env.DB.prepare('SELECT * FROM return_items WHERE return_id=?').bind(r.id).all<Row>()).results;
   if(!Array.isArray(b.items)||b.items.length!==lines.length||new Set(b.items.map((x:Row)=>x.productId)).size!==lines.length)return bad(c,'Inspect every return item exactly once');
   status='INSPECTED';statements.push(c.env.DB.prepare("UPDATE return_requests SET status='INSPECTED',inspected_by=?,inspected_at=? WHERE id=?").bind(u.sub,Date.now(),r.id));
   for(const item of b.items){
    const line=lines.find(x=>x.product_id===item.productId);const sf=item.saleableFreeQuantity??0,df=item.damagedFreeQuantity??0;
    if(!line||![item.saleableQuantity,item.damagedQuantity,sf,df].every(quantity)||item.saleableQuantity+item.damagedQuantity!==line.requested_quantity||sf+df!==line.free_quantity)return bad(c,'Disposition must account for all received paid and free units');
    totalCreditNotePaise+=(item.saleableQuantity+item.damagedQuantity)*line.unit_price_paise;
    statements.push(c.env.DB.prepare('UPDATE return_items SET saleable_quantity=?,damaged_quantity=?,saleable_free_quantity=?,damaged_free_quantity=? WHERE id=?').bind(item.saleableQuantity,item.damagedQuantity,sf,df,line.id));
    const restock=item.saleableQuantity+sf;
    if(restock){
     statements.push(c.env.DB.prepare('UPDATE products SET stock_quantity=stock_quantity+? WHERE id=? AND company_id=?').bind(restock,item.productId,u.company_id));
     statements.push(c.env.DB.prepare("INSERT INTO stock_adjustments(id,company_id,product_id,user_id,change_quantity,reason,stock_after,notes,idempotency_key,created_at) SELECT ?,?,?,?,?, 'RETURN_RESTOCK',stock_quantity,?,?,? FROM products WHERE id=? AND company_id=?").bind(crypto.randomUUID(),u.company_id,item.productId,u.sub,restock,r.id,`return_stock_${r.id}_${item.productId}`,Date.now(),item.productId,u.company_id));
    }
   }
   statements.push(c.env.DB.prepare('UPDATE return_requests SET credit_paise=? WHERE id=?').bind(totalCreditNotePaise,r.id));
  }else{
   if(!b.notes?.trim())return bad(c,'Credit approval reason required');status='CREDITED';totalCreditNotePaise=r.credit_paise;
   const invoice=await c.env.DB.prepare('SELECT * FROM invoices WHERE order_id=? AND company_id=?').bind(r.order_id,u.company_id).first<Row>();if(!invoice)return bad(c,'Original invoice missing',409);
   statements.push(c.env.DB.prepare("UPDATE return_requests SET status='CREDITED',credited_by=?,credited_at=? WHERE id=?").bind(u.sub,Date.now(),r.id));
   statements.push(c.env.DB.prepare('INSERT INTO return_credit_notes VALUES(?,?,?,?,?,?)').bind(r.id,u.company_id,invoice.id,totalCreditNotePaise,u.sub,Date.now()));
   statements.push(c.env.DB.prepare('UPDATE invoices SET credited_paise=credited_paise+? WHERE id=?').bind(totalCreditNotePaise,invoice.id));
   statements.push(c.env.DB.prepare('UPDATE retailers SET outstanding_amount_paise=outstanding_amount_paise-? WHERE id=? AND company_id=?').bind(totalCreditNotePaise,r.retailer_id,u.company_id));
   statements.push(c.env.DB.prepare(`INSERT INTO payment_ledger(id,order_id,invoice_id,company_id,retailer_id,entry_type,amount_paise,balance_after_paise,payment_method,collected_by,created_at,idempotency_key) SELECT ?,?,?,?,?,'RETURN_CREDIT_NOTE',?,outstanding_amount_paise,'CREDIT_NOTE',?,?,? FROM retailers WHERE id=?`).bind(crypto.randomUUID(),r.order_id,invoice.id,u.company_id,r.retailer_id,totalCreditNotePaise,u.sub,Date.now(),`return_credit_${r.id}`,r.retailer_id));
  }
  statements.push(audit(c,`RETURN_${step.toUpperCase()}`,r.id,b));return commit(c,op,b,statements,{success:true,status,totalCreditNotePaise});
 });
 return app;
}
