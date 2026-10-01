import type { Context } from 'hono';

export async function sha256(value: string): Promise<string> {
 const bytes=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value));
 return Array.from(new Uint8Array(bytes),b=>b.toString(16).padStart(2,'0')).join('');
}
/** Atomic D1 counters across Worker instances; no credentials or raw IP persisted. */
export async function rateLimit(c: Context<any>, scope: string, subject: string, limit: number, seconds=900): Promise<boolean> {
 const start=Math.floor(Date.now()/1000/seconds)*seconds;
 const subjectHash=await sha256(`${scope}:${subject}`);
 const row=await (c.env.DB as D1Database).prepare(`INSERT INTO auth_rate_limits VALUES(?,?,?,1)
 ON CONFLICT(scope,subject_hash,window_start) DO UPDATE SET attempts=attempts+1 RETURNING attempts`).bind(scope,subjectHash,start).first<{attempts:number}>();
 if ((row?.attempts ?? limit+1)>limit) { c.header('Retry-After',String(seconds));return false; }
 return true;
}
export const requestIp=(c:Context<any>)=>c.req.header('CF-Connecting-IP') || 'local';
export function validPassword(value:unknown):value is string {
 return typeof value==='string'&&value.length>=12&&new TextEncoder().encode(value).length<=72;
}
