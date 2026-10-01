from pathlib import Path
p=Path('backend/src/index.ts');s=p.read_text(encoding='utf-8')
s="import { bodyLimit } from 'hono/body-limit';\nimport { rateLimit, requestIp } from './security';\n"+s
s=s.replace("const app = new Hono<{ Bindings: Bindings; Variables: Variables }>();", """const app = new Hono<{ Bindings: Bindings; Variables: Variables }>();
app.use('*', bodyLimit({ maxSize: 256 * 1024, onError: c => c.json({ error: 'Request exceeds 256 KiB' }, 413) }));
app.onError((error, c) => {
  if (error instanceof SyntaxError) return c.json({ error: 'Invalid JSON request' }, 400);
  console.error(JSON.stringify({ event: 'request_failed', method: c.req.method, path: c.req.path }));
  return c.json({ error: 'The request could not be completed. Refresh and retry.' }, 500);
});""")
s=s.replace("  if (!username || !password) {", "  if (typeof username !== 'string' || username.length > 120 || typeof password !== 'string' || new TextEncoder().encode(password).length > 72 || !username || !password) {")
at=s.index("  //",s.index("app.post('/auth/login'"))
# Insert before DB lookup, after shape validation.
a=s.index("  const user =",s.index("app.post('/auth/login'"))
s=s[:a]+"""  if (!await rateLimit(c, 'login-ip', requestIp(c), 100) || !await rateLimit(c, 'login-account', username.trim().toLowerCase(), 30)) {
    return c.json({ error: 'Too many login attempts. Try again later.' }, 429);
  }
"""+s[a:]
a=s.index('  const updateResult =',s.index("app.post('/auth/refresh'"));b=s.index('  const accessToken =',a)
s=s[:a]+"""  try {
    await c.env.DB.batch([
      c.env.DB.prepare('INSERT INTO revoked_refresh_tokens (token_hash, session_id, user_id, revoked_at) VALUES (?, ?, ?, ?)')
        .bind(refreshTokenHash, session.id, session.user_id, nowSec),
      c.env.DB.prepare('UPDATE sessions SET refresh_token_hash = ?, last_active_at = ?, expires_at = ? WHERE id = ? AND refresh_token_hash = ? AND is_revoked = 0')
        .bind(newRefreshTokenHash, nowSec, nowSec + refreshExpirySeconds, session.id, refreshTokenHash)
    ]);
  } catch {
    // Replay includes concurrent reuse: require a fresh sign-in for that session.
    await c.env.DB.prepare('UPDATE sessions SET is_revoked = 1 WHERE id = ?').bind(session.id).run();
    return c.json({ error: 'Refresh token reused or session revoked' }, 401);
  }

"""+s[b:]
s=s.replace("  if (payload.exp && payload.exp < nowSec)","  if (!Number.isFinite(payload.exp) || payload.exp <= nowSec)")
# Keep validation failures useful, and never leak SQL in public responses/logs.
s=s.replace("console.error('Order creation error:', e);", "console.error(JSON.stringify({ event: 'order_creation_rejected' }));")
p.write_text(s,encoding='utf-8')
p=Path('backend/src/daily-cycle.ts');s=p.read_text().replace("status IN ('OUT_FOR_DELIVERY','DELIVERED')", "status IN ('OUT_FOR_DELIVERY','DELIVERED','PARTIALLY_DELIVERED')");p.write_text(s)
p=Path('app/src/main/java/com/routeflow/app/data/repository/OfflineOrderRepository.kt');s=p.read_text();a=s.index('    override suspend fun failDelivery(');b=s.index('    override suspend fun getUndeliveredGoods',a)
s=s[:a]+'''    override suspend fun failDelivery(
        orderId: String, reason: String, rescheduledDate: String?, notes: String?
    ): Result<Unit> = Result.failure(UnsupportedOperationException(
        "Recording a failed delivery requires server confirmation of stock custody and credit release."
    ))

'''+s[b:];p.write_text(s)
