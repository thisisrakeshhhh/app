import { test, before } from 'node:test';
import assert from 'node:assert/strict';
const base=process.env.ROUTEFLOW_TEST_URL;
if(!base)throw new Error('Use run-isolated.mjs; never run financial regression against business data');
const tokens={};
const key=()=>crypto.randomUUID();
async function req(role,path,body,method){
 const r=await fetch(base+path,{method:method||(body?'POST':'GET'),headers:{'Content-Type':'application/json',Authorization:`Bearer ${tokens[role]}`},...(body?{body:JSON.stringify(body)}:{})});
 return {httpStatus:r.status,...await r.json()};
}
const ok=r=>{assert.equal(r.httpStatus,200,JSON.stringify(r));return r;};
before(async()=>{for(const role of ['owner','sales','warehouse','delivery','delivery2','owner_comp2'])tokens[role]=(await req(role,'/auth/login',{username:role,password:'password123'})).access_token;});
async function balance(){return (await req('owner','/retailers')).find(r=>r.id==='R1').outstandingAmountPaise;}
// GET array responses are intentionally read directly (object-spread would lose Array methods).
async function retailers(){return (await fetch(base+'/retailers',{headers:{Authorization:`Bearer ${tokens.owner}`}})).json();}
async function due(){return (await retailers()).find(r=>r.id==='R1').outstandingAmountPaise;}
test('pending UPI and cheque do not settle; concurrent settlement and reversal apply once',async()=>{
 for(const paymentMethod of ['UPI','CHEQUE']){
  const before=await due();const r=ok(await req('sales','/collections',{retailerId:'R1',amountPaise:1001,paymentMethod,reference:'test-reference',idempotencyKey:key()}));
  assert.equal(r.httpStatus,200);assert.equal(await due(),before);
  const b={action:paymentMethod==='CHEQUE'?'CLEAR':'VERIFY',reason:'Verified independently against bank statement',idempotencyKey:key()};
  const raced=await Promise.all([req('owner',`/collections/${r.collectionId}/review`,b),req('owner',`/collections/${r.collectionId}/review`,b)]);
  assert.ok(raced.every(x=>x.httpStatus===200));assert.equal(await due(),before-1001);
  const reverse={action:'REVERSE',reason:'Approved correction',idempotencyKey:key()};
  const reversed=await Promise.all([req('owner',`/collections/${r.collectionId}/review`,reverse),req('owner',`/collections/${r.collectionId}/review`,reverse)]);
  assert.ok(reversed.every(x=>x.httpStatus===200));assert.equal(await due(),before);
  assert.equal((await req('owner',`/collections/${r.collectionId}/review`,{...reverse,idempotencyKey:key()})).httpStatus,409);
 }
});
test('role, retailer assignment, replay and shift ownership are enforced',async()=>{
 const b={retailerId:'R1',amountPaise:100,paymentMethod:'CASH',idempotencyKey:key()};
 assert.equal((await req('warehouse','/collections',b)).httpStatus,403);
 assert.equal((await req('sales','/collections',{...b,retailerId:'ret_comp2_1'})).httpStatus,403);
 const owned=ok(await req('sales','/collections',b));assert.ok(owned.collectionId);
 assert.equal((await req('owner_comp2','/collections',b)).httpStatus,403);
 const shiftId=key(),startTime=Date.now()-1000;
 ok(await req('sales','/shifts/start',{shiftId,startTime,idempotencyKey:key()}));
 const points=[{id:key(),latitude:26.8,longitude:75.7,accuracy:15,timestamp:Date.now()-500}];
 assert.equal((await req('delivery','/shifts/locations',{shiftId,points})).httpStatus,403);
 const endTime=Date.now();ok(await req('sales','/shifts/end',{shiftId,endTime,idempotencyKey:key()}));
 ok(await req('sales','/shifts/locations',{shiftId,points}));ok(await req('sales','/shifts/locations',{shiftId,points}));
 assert.equal((await req('sales','/shifts/locations',{shiftId,points:[{...points[0],id:key(),timestamp:endTime+1}]})).httpStatus,400);
});
async function order(retailerId='R1',qty=1,product='P2',price=12000){
 const id=key();const r=await req('sales','/orders',{order:{id,retailerId,totalAmountPaise:qty*price},items:[{id:key(),productId:product,quantity:qty,pricePaiseAtTime:price}],idempotencyKey:key()});return {...r,id};
}
async function deliver(o,method='CREDIT'){
 ok(await req('owner',`/orders/${o.id}/approve`,{}));ok(await req('warehouse',`/orders/${o.id}/start-picking`,{}));
 const detail=await req('owner',`/orders/${o.id}`);
 for(const i of detail.items)ok(await req('warehouse',`/orders/${o.id}/pick-item`,{productId:i.productId,isPicked:true}));
 ok(await req('warehouse',`/orders/${o.id}/pack`,{}));ok(await req('warehouse',`/orders/${o.id}/dispatch`,{deliveryEmployeeId:'user_delivery'}));
 const proof=ok(await req('delivery',`/orders/${o.id}/request-otp`,{}));assert.equal(proof.deliveryStatus,'SIMULATED');assert.match(proof.message,/no SMS sent/);
 ok(await req('delivery',`/orders/${o.id}/deliver`,{paymentMethod:method,recipientName:'Test Receiver',otp:proof.debugOtp}));
 assert.equal((await req('delivery2',`/orders/${o.id}/deliver`,{paymentMethod:method})).httpStatus,403);
}
test('concurrent orders reserve credit and rejection releases it',async()=>{
 const rid=key();ok(await req('owner','/retailers',{id:rid,name:'Credit race',beatId:'BEAT-04',address:'Test',contactNumber:'9000000001',creditLimitPaise:15000}));
 const raced=await Promise.all([order(rid),order(rid)]);assert.equal(raced.filter(x=>x.httpStatus===200).length,1,JSON.stringify(raced));
 const win=raced.find(x=>x.httpStatus===200);ok(await req('owner',`/orders/${win.id}/reject`,{reason:'Release reservation'}));ok(await order(rid));
});
test('concurrent returns reserve quantities; free units are not credited and restock/credit happen once',async()=>{
 const o=ok(await order('R1',10,'P1',45000));await deliver(o);
 const create=()=>req('sales','/returns',{orderId:o.id,items:[{productId:'P1',requestedQuantity:6,freeQuantity:1}],idempotencyKey:key()});
 const raced=await Promise.all([create(),create()]);assert.equal(raced.filter(x=>x.httpStatus===200).length,1,JSON.stringify(raced));
 const id=raced.find(x=>x.httpStatus===200).returnId;
 ok(await req('owner',`/returns/${id}/authorize`,{action:'APPROVE',notes:'Authorized',idempotencyKey:key()}));
 ok(await req('warehouse',`/returns/${id}/receive`,{notes:'Physical goods received',idempotencyKey:key()}));
 const inspection={items:[{productId:'P1',saleableQuantity:5,damagedQuantity:1,saleableFreeQuantity:0,damagedFreeQuantity:1}],idempotencyKey:key()};
 const inspected=ok(await req('warehouse',`/returns/${id}/inspect`,inspection));assert.equal(inspected.totalCreditNotePaise,270000);
 ok(await req('warehouse',`/returns/${id}/inspect`,inspection));
 const before=await due(),credit={notes:'Approved credit',idempotencyKey:key()};
 ok(await req('owner',`/returns/${id}/credit`,credit));ok(await req('owner',`/returns/${id}/credit`,credit));assert.equal(await due(),before-270000);
 assert.equal((await create()).httpStatus,409);
});
test('cash handover reservation and concurrent acknowledgement cannot settle twice',async()=>{
 ok(await req('sales','/collections',{retailerId:'R1',amountPaise:20000,paymentMethod:'CASH',idempotencyKey:key()}));
 const b={amountPaise:10000,idempotencyKey:key()};const r=ok(await req('sales','/handovers/request',b));ok(await req('sales','/handovers/request',b));
 assert.equal((await req('sales','/handovers/request',{amountPaise:10000,idempotencyKey:key()})).httpStatus,400);
 const before=await req('sales','/handovers/summary');const ack={action:'ACCEPT',receivedAmountPaise:9000,notes:'1000 shortage retained in employee custody',idempotencyKey:key()};
 const raced=await Promise.all([req('owner',`/owner/handovers/${r.handoverId}/acknowledge`,ack),req('owner',`/owner/handovers/${r.handoverId}/acknowledge`,ack)]);assert.ok(raced.every(x=>x.httpStatus===200),JSON.stringify(raced));
 assert.equal((await req('sales','/handovers/summary')).cashHeldPaise,before.cashHeldPaise-9000);
});
