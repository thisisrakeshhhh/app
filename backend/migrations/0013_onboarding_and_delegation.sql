-- 0013_onboarding_and_delegation.sql
-- Public owner onboarding, single-use employee invite tokens,
-- Team Leader / Admin delegation, teams, last-owner protection, and security events.

-- 1. Employee invitations table with single-use hashed token and status lifecycle
CREATE TABLE IF NOT EXISTS employee_invitations (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    username TEXT NOT NULL,
    role TEXT NOT NULL, -- ADMIN, SALESPERSON, WAREHOUSE_MANAGER, DELIVERY_EXECUTIVE
    beat_id TEXT,
    warehouse_id TEXT,
    status TEXT NOT NULL DEFAULT 'INVITED', -- INVITED, ACCEPTED, EXPIRED, CANCELLED
    expires_at INTEGER NOT NULL,
    created_by TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    accepted_at INTEGER,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (created_by) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_invitations_token ON employee_invitations(token_hash);
CREATE INDEX IF NOT EXISTS idx_invitations_company ON employee_invitations(company_id);

-- 2. Teams table for delegating beats and team members to Team Leaders / Admins
CREATE TABLE IF NOT EXISTS teams (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    name TEXT NOT NULL,
    leader_user_id TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (leader_user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS team_memberships (
    team_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    company_id TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY (team_id, user_id),
    FOREIGN KEY (team_id) REFERENCES teams(id),
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (company_id) REFERENCES companies(id)
);

-- 3. Security audit events (for sensitive actions like ownership transfer, reauth, session revocation)
CREATE TABLE IF NOT EXISTS security_events (
    id TEXT PRIMARY KEY,
    company_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    event_type TEXT NOT NULL, -- PASSWORD_CHANGE, SESSION_REVOKED, OWNERSHIP_TRANSFER, REAUTH_SUCCESS, INVITE_SENT
    details TEXT,
    ip_address TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (company_id) REFERENCES companies(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_sec_events_user ON security_events(company_id, user_id, created_at);

-- 4. Add status, phone_number, team_id to users table
ALTER TABLE users ADD COLUMN status TEXT DEFAULT 'ACTIVE';
ALTER TABLE users ADD COLUMN phone_number TEXT;
ALTER TABLE users ADD COLUMN team_id TEXT;

-- 5. Last-owner protection trigger: prevents deleting or deactivating the last active OWNER
CREATE TRIGGER IF NOT EXISTS prevent_last_owner_deactivation
BEFORE UPDATE OF is_active, role ON users
FOR EACH ROW
WHEN OLD.role = 'OWNER' AND (NEW.is_active = 0 OR NEW.role != 'OWNER')
BEGIN
    SELECT CASE WHEN (
        SELECT COUNT(*) FROM users
        WHERE company_id = OLD.company_id AND role = 'OWNER' AND is_active = 1 AND id != OLD.id
    ) < 1
    THEN RAISE(ABORT, 'Cannot deactivate or change role of the company''s last active owner') END;
END;
