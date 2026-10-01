import { Hono } from 'hono';
import bcrypt from 'bcryptjs';
import { sha256, validPassword, rateLimit, requestIp } from './security';
import { sign } from '@tsndr/cloudflare-worker-jwt';

export function onboardingRouter(authMiddleware: any) {
  const router = new Hono<{ Bindings: any; Variables: any }>();

  // ── 1. Public Owner Onboarding ──────────────────────────────────────────────
  router.post('/auth/register-owner', async (c) => {
  if (!await rateLimit(c, 'signup-ip', requestIp(c), 10, 3600)) {
    return c.json({ error: 'Too many registration attempts from this network. Try again later.' }, 429);
  }

  const body = await c.req.json().catch(() => ({}));
  const businessName = (body.businessName || body.business_name || '').trim();
  const fullName = (body.fullName || body.full_name || '').trim();
  const username = (body.username || '').trim().toLowerCase();
  const password = body.password;
  const contactNumber = (body.contactNumber || body.contact_number || '').trim();
  const address = (body.address || '').trim();

  if (!businessName || businessName.length < 3 || businessName.length > 120) {
    return c.json({ error: 'Business name must be between 3 and 120 characters' }, 400);
  }
  if (!fullName || fullName.length < 2 || fullName.length > 100) {
    return c.json({ error: 'Full name is required' }, 400);
  }
  if (!username || !/^[a-z0-9_]{3,40}$/.test(username)) {
    return c.json({ error: 'Username must be 3-40 alphanumeric characters or underscores' }, 400);
  }
  if (!validPassword(password)) {
    return c.json({ error: 'Password must be at least 12 characters and at most 72 bytes' }, 400);
  }

  const db = c.env.DB as D1Database;
  const existing = await db.prepare('SELECT id FROM users WHERE username = ?').bind(username).first();
  if (existing) {
    return c.json({ error: 'Username is already taken' }, 409);
  }

  const companyId = `comp_${crypto.randomUUID().replace(/-/g, '').slice(0, 12)}`;
  const userId = `user_own_${crypto.randomUUID().replace(/-/g, '').slice(0, 8)}`;
  const salt = bcrypt.genSaltSync(12);
  const passwordHash = bcrypt.hashSync(password, salt);
  const now = Date.now();
  const nowSec = Math.floor(now / 1000);

  const statements = [
    db.prepare('INSERT INTO companies (id, name, created_at) VALUES (?, ?, ?)')
      .bind(companyId, businessName, now),
    db.prepare(`INSERT INTO users (id, company_id, username, password_hash, full_name, role, is_active, status, phone_number, created_at)
      VALUES (?, ?, ?, ?, ?, 'OWNER', 1, 'ACTIVE', ?, ?)`
    ).bind(userId, companyId, username, passwordHash, fullName, contactNumber || null, now),
    db.prepare('INSERT INTO security_events (id, company_id, user_id, event_type, details, ip_address, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
      .bind(crypto.randomUUID(), companyId, userId, 'BUSINESS_REGISTERED', `Registered business "${businessName}" with initial owner`, requestIp(c), now),
    db.prepare('INSERT INTO audit_logs (id, company_id, user_id, action, entity_id, details, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?)')
      .bind(crypto.randomUUID(), companyId, userId, 'OWNER_REGISTERED', userId, `Owner registered business ${businessName}`, now)
  ];

  // Also create initial session
  const sessionId = crypto.randomUUID();
  const rawRefreshToken = crypto.randomUUID() + crypto.randomUUID();
  const refreshTokenHash = await sha256(rawRefreshToken);
  const refreshExpirySeconds = parseInt(c.env.JWT_REFRESH_EXPIRY || '2592000', 10);
  const accessExpirySeconds = parseInt(c.env.JWT_ACCESS_EXPIRY || '900', 10);

  statements.push(
    db.prepare('INSERT INTO sessions (id, user_id, company_id, device_id, refresh_token_hash, is_revoked, created_at, last_active_at, expires_at) VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?)')
      .bind(sessionId, userId, companyId, body.deviceId || 'web-app', refreshTokenHash, nowSec, nowSec, nowSec + refreshExpirySeconds)
  );

  try {
    await db.batch(statements);
  } catch (err: any) {
    if (err.message && err.message.includes('UNIQUE constraint')) {
      return c.json({ error: 'Username or company already exists' }, 409);
    }
    return c.json({ error: 'Registration failed. Please retry.' }, 500);
  }

  const accessToken = await sign({
    sub: userId,
    sid: sessionId,
    username,
    role: 'OWNER',
    company_id: companyId,
    exp: nowSec + accessExpirySeconds,
    iat: nowSec
  }, c.env.JWT_SECRET);

  return c.json({
    success: true,
    message: 'Business created successfully',
    access_token: accessToken,
    refresh_token: rawRefreshToken,
    expires_in: accessExpirySeconds,
    user: {
      id: userId,
      username,
      name: fullName,
      fullName,
      role: 'OWNER',
      company_id: companyId,
      companyId,
      businessName,
      status: 'ACTIVE'
    }
  }, 201);
});

// ── 2. Create Single-Use Expiring Employee Invitation (Owner / Admin) ───────
  router.post('/employees/invite', authMiddleware, async (c) => {
    const user = c.get('user');
    if (!user || (user.role !== 'OWNER' && user.role !== 'ADMIN')) {
      return c.json({ error: 'Permission denied: Owner or Admin role required' }, 403);
    }

  const body = await c.req.json().catch(() => ({}));
  const fullName = (body.fullName || body.full_name || '').trim();
  const username = (body.username || '').trim().toLowerCase();
  const role = body.role;
  const beatId = body.beatId || body.beat_id || null;
  const warehouseId = body.warehouseId || body.warehouse_id || null;

  const VALID_ROLES = ['ADMIN', 'SALESPERSON', 'WAREHOUSE_MANAGER', 'DELIVERY_EXECUTIVE'];
  if (!VALID_ROLES.includes(role)) {
    return c.json({ error: `Invalid role. Allowed: ${VALID_ROLES.join(', ')}` }, 400);
  }
  if (!fullName || fullName.length < 2) {
    return c.json({ error: 'Full name is required' }, 400);
  }
  if (!username || !/^[a-z0-9_]{3,40}$/.test(username)) {
    return c.json({ error: 'Username must be 3-40 alphanumeric characters or underscores' }, 400);
  }

  const db = c.env.DB as D1Database;
  const existingUser = await db.prepare('SELECT id FROM users WHERE username = ?').bind(username).first();
  if (existingUser) {
    return c.json({ error: 'Username is already taken' }, 409);
  }

  const existingInvite = await db.prepare(
    "SELECT id FROM employee_invitations WHERE username = ? AND company_id = ? AND status = 'INVITED' AND expires_at > ?"
  ).bind(username, user.company_id, Date.now()).first();
  if (existingInvite) {
    return c.json({ error: 'An active invitation already exists for this username' }, 409);
  }

  // Generate secure single-use invitation token
  const rawInviteToken = `rf_inv_${crypto.randomUUID().replace(/-/g, '')}${crypto.randomUUID().replace(/-/g, '').slice(0, 16)}`;
  const tokenHash = await sha256(rawInviteToken);
  const invitationId = `inv_${crypto.randomUUID().replace(/-/g, '').slice(0, 10)}`;
  const now = Date.now();
  const expiresAt = now + 7 * 24 * 60 * 60 * 1000; // 7 days

  const statements = [
    db.prepare(`INSERT INTO employee_invitations (id, company_id, token_hash, full_name, username, role, beat_id, warehouse_id, status, expires_at, created_by, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'INVITED', ?, ?, ?)`
    ).bind(invitationId, user.company_id, tokenHash, fullName, username, role, beatId, warehouseId, expiresAt, user.sub, now),
    db.prepare('INSERT INTO security_events (id, company_id, user_id, event_type, details, ip_address, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
      .bind(crypto.randomUUID(), user.company_id, user.sub, 'INVITE_SENT', `Invited ${fullName} (${username}) as ${role}`, requestIp(c), now)
  ];

  await db.batch(statements);

  return c.json({
    success: true,
    invitation: {
      id: invitationId,
      fullName,
      username,
      role,
      beatId,
      warehouseId,
      expiresAt,
      inviteToken: rawInviteToken
    }
  }, 201);
});

// ── 3. Accept Employee Invitation & Create Password (Public) ────────────────
  router.post('/auth/accept-invite', async (c) => {
  if (!await rateLimit(c, 'accept-invite-ip', requestIp(c), 30, 3600)) {
    return c.json({ error: 'Too many attempts. Try again later.' }, 429);
  }

  const body = await c.req.json().catch(() => ({}));
  const inviteToken = (body.inviteToken || body.invite_token || '').trim();
  const password = body.password;

  if (!inviteToken || inviteToken.length < 16) {
    return c.json({ error: 'Valid invitation token is required' }, 400);
  }
  if (!validPassword(password)) {
    return c.json({ error: 'Password must be at least 12 characters and at most 72 bytes' }, 400);
  }

  const db = c.env.DB as D1Database;
  const tokenHash = await sha256(inviteToken);
  const now = Date.now();

  const invite = await db.prepare(
    "SELECT * FROM employee_invitations WHERE token_hash = ? AND status = 'INVITED'"
  ).bind(tokenHash).first<any>();

  if (!invite) {
    return c.json({ error: 'Invalid or already used invitation token' }, 404);
  }
  if (invite.expires_at < now) {
    await db.prepare("UPDATE employee_invitations SET status = 'EXPIRED' WHERE id = ?").bind(invite.id).run();
    return c.json({ error: 'This invitation has expired. Contact your business owner for a new invite.' }, 410);
  }

  const salt = bcrypt.genSaltSync(12);
  const passwordHash = bcrypt.hashSync(password, salt);
  const userId = `user_${crypto.randomUUID().replace(/-/g, '').slice(0, 8)}`;

  const statements = [
    db.prepare("UPDATE employee_invitations SET status = 'ACCEPTED', accepted_at = ? WHERE id = ? AND status = 'INVITED'")
      .bind(now, invite.id),
    db.prepare(`INSERT INTO users (id, company_id, username, password_hash, full_name, role, is_active, status, created_at)
      VALUES (?, ?, ?, ?, ?, ?, 1, 'ACTIVE', ?)`
    ).bind(userId, invite.company_id, invite.username, passwordHash, invite.full_name, invite.role, now),
    db.prepare('INSERT INTO security_events (id, company_id, user_id, event_type, details, ip_address, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
      .bind(crypto.randomUUID(), invite.company_id, userId, 'INVITE_ACCEPTED', `Accepted invitation and initialized account password for ${invite.username}`, requestIp(c), now)
  ];

  if (invite.role === 'SALESPERSON' && invite.beat_id) {
    statements.push(
      db.prepare('INSERT OR REPLACE INTO user_beat_assignments (user_id, beat_id, company_id, created_at) VALUES (?, ?, ?, ?)')
        .bind(userId, invite.beat_id, invite.company_id, now)
    );
  }

  try {
    await db.batch(statements);
  } catch (err: any) {
    if (err.message && err.message.includes('UNIQUE constraint')) {
      return c.json({ error: 'Username is already registered' }, 409);
    }
    return c.json({ error: 'Failed to activate account. Retry.' }, 500);
  }

  return c.json({
    success: true,
    message: 'Your password has been created. You can now sign in with your username.',
    username: invite.username
  });
});

// ── 4. Session Listing & Remote Revocation ──────────────────────────────────
  router.get('/auth/sessions', authMiddleware, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Authentication required' }, 401);

    const db = c.env.DB as D1Database;
    const { results } = await db.prepare(
      `SELECT s.id, s.device_id AS deviceId, s.is_revoked AS isRevoked, s.created_at AS createdAt, s.last_active_at AS lastActiveAt, s.expires_at AS expiresAt,
              u.username, u.full_name AS fullName, u.role
       FROM sessions s JOIN users u ON u.id = s.user_id
       WHERE s.company_id = ? AND (? = 'OWNER' OR s.user_id = ?) AND s.is_revoked = 0 AND s.expires_at > ?
       ORDER BY s.last_active_at DESC`
    ).bind(user.company_id, user.role, user.sub, Math.floor(Date.now() / 1000)).all();

    return c.json({ sessions: results });
  });

  router.post('/auth/sessions/:id/revoke', authMiddleware, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Authentication required' }, 401);

    const sessionId = c.req.param('id');
    const db = c.env.DB as D1Database;
    const session = await db.prepare(
      'SELECT * FROM sessions WHERE id = ? AND company_id = ?'
    ).bind(sessionId, user.company_id).first<any>();

    if (!session) return c.json({ error: 'Session not found' }, 404);
    if (user.role !== 'OWNER' && session.user_id !== user.sub) {
      return c.json({ error: 'Permission denied: cannot revoke sessions of other users' }, 403);
    }

    const now = Date.now();
    const nowSec = Math.floor(now / 1000);

    await db.batch([
      db.prepare('UPDATE sessions SET is_revoked = 1 WHERE id = ?').bind(sessionId),
      db.prepare('INSERT OR REPLACE INTO revoked_refresh_tokens (token_hash, session_id, user_id, revoked_at) VALUES (?, ?, ?, ?)')
        .bind(session.refresh_token_hash, session.id, session.user_id, nowSec),
      db.prepare('INSERT INTO security_events (id, company_id, user_id, event_type, details, ip_address, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
        .bind(crypto.randomUUID(), user.company_id, user.sub, 'SESSION_REVOKED', `Revoked session ${sessionId} for user ${session.user_id}`, requestIp(c), now)
    ]);

    return c.json({ success: true, message: 'Session revoked successfully' });
  });

  // ── 5. Change Password & Security Audit ──────────────────────────────────────
  router.post('/auth/change-password', authMiddleware, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Authentication required' }, 401);

    const body = await c.req.json().catch(() => ({}));
    const oldPassword = body.oldPassword || body.old_password;
    const newPassword = body.newPassword || body.new_password;

    if (typeof oldPassword !== 'string' || !oldPassword) {
      return c.json({ error: 'Current password is required' }, 400);
    }
    if (!validPassword(newPassword)) {
      return c.json({ error: 'New password must be at least 12 characters' }, 400);
    }
    if (oldPassword === newPassword) {
      return c.json({ error: 'New password must be different from current password' }, 400);
    }

    const db = c.env.DB as D1Database;
    const currentUser = await db.prepare('SELECT password_hash FROM users WHERE id = ? AND company_id = ?')
      .bind(user.sub, user.company_id).first<any>();

    if (!currentUser || !bcrypt.compareSync(oldPassword, currentUser.password_hash)) {
      return c.json({ error: 'Current password is incorrect' }, 401);
    }

    const salt = bcrypt.genSaltSync(12);
    const newPasswordHash = bcrypt.hashSync(newPassword, salt);
    const now = Date.now();

    await db.batch([
      db.prepare('UPDATE users SET password_hash = ? WHERE id = ? AND company_id = ?')
        .bind(newPasswordHash, user.sub, user.company_id),
      db.prepare('INSERT INTO security_events (id, company_id, user_id, event_type, details, ip_address, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
        .bind(crypto.randomUUID(), user.company_id, user.sub, 'PASSWORD_CHANGE', 'Password changed by user; other sessions revoked', requestIp(c), now),
      // Revoke all OTHER sessions for this user to enforce fresh login on all other devices
      db.prepare('UPDATE sessions SET is_revoked = 1 WHERE user_id = ? AND id != ?')
        .bind(user.sub, user.sid || '')
    ]);

    return c.json({ success: true, message: 'Password updated. Other active sessions revoked.' });
  });

  // ── 6. Reauthentication for Sensitive Actions ───────────────────────────────
  router.post('/auth/reauthenticate', authMiddleware, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Authentication required' }, 401);

    const { password } = await c.req.json().catch(() => ({}));
    if (typeof password !== 'string' || !password) {
      return c.json({ error: 'Password required for verification' }, 400);
    }

    const db = c.env.DB as D1Database;
    const currentUser = await db.prepare('SELECT password_hash FROM users WHERE id = ? AND company_id = ?')
      .bind(user.sub, user.company_id).first<any>();

    if (!currentUser || !bcrypt.compareSync(password, currentUser.password_hash)) {
      return c.json({ error: 'Password verification failed' }, 401);
    }

    const nowSec = Math.floor(Date.now() / 1000);
    const reauthToken = await sign({
      sub: user.sub,
      reauth: true,
      exp: nowSec + 300 // Valid for 5 minutes
    }, c.env.JWT_SECRET);

    await db.prepare('INSERT INTO security_events (id, company_id, user_id, event_type, details, ip_address, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)')
      .bind(crypto.randomUUID(), user.company_id, user.sub, 'REAUTH_SUCCESS', 'Reauthenticated for sensitive owner action', requestIp(c), Date.now()).run();

    return c.json({ success: true, reauthToken, expiresInSeconds: 300 });
  });

  // ── 7. Teams and Team Leader Delegation ─────────────────────────────────────
  router.get('/teams', authMiddleware, async (c) => {
    const user = c.get('user');
    if (!user) return c.json({ error: 'Authentication required' }, 401);

    const db = c.env.DB as D1Database;
    const { results: teams } = await db.prepare(
      `SELECT t.id, t.name, t.leader_user_id AS leaderUserId, u.full_name AS leaderName, t.created_at AS createdAt
       FROM teams t LEFT JOIN users u ON u.id = t.leader_user_id
       WHERE t.company_id = ? ORDER BY t.name ASC`
    ).bind(user.company_id).all();

    return c.json({ teams });
  });

  router.post('/teams', authMiddleware, async (c) => {
    const user = c.get('user');
    if (!user || user.role !== 'OWNER') {
      return c.json({ error: 'Permission denied: owner role required to create teams' }, 403);
    }

    const { name, leaderUserId } = await c.req.json().catch(() => ({}));
    if (!name || typeof name !== 'string' || name.trim().length < 2) {
      return c.json({ error: 'Team name is required' }, 400);
    }

    const db = c.env.DB as D1Database;
    const teamId = `team_${crypto.randomUUID().replace(/-/g, '').slice(0, 10)}`;
    const now = Date.now();

    await db.prepare(
      'INSERT INTO teams (id, company_id, name, leader_user_id, created_at) VALUES (?, ?, ?, ?, ?)'
    ).bind(teamId, user.company_id, name.trim(), leaderUserId || null, now).run();

    return c.json({ success: true, team: { id: teamId, name: name.trim(), leaderUserId } }, 201);
  });

  return router;
}
