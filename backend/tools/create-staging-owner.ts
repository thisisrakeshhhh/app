/**
 * create-staging-owner.ts
 *
 * Provisions an OWNER user in the staging D1 database.
 * Migrations create NO login accounts — this script must be run once after migrations.
 *
 * SECURITY RULES:
 *  - Never pass password on command line (it goes into shell history).
 *  - Never print plaintext password to stdout.
 *  - Input is read from stdin using Node's readline so it is not captured by the shell.
 *  - Generated SQL is written to a temp file, printed for review, and the path is shown.
 *  - Clean up the temp file after applying.
 *  - The script refuses to proceed if the username already exists (idempotency guard).
 *
 * Usage:
 *   npx tsx backend/tools/create-staging-owner.ts
 *
 * Then apply the generated file (shown at the end):
 *   npx wrangler d1 execute routeflow-db-staging \
 *     --config backend/wrangler.staging.toml \
 *     --remote --file /path/to/reviewed-provision.sql
 *
 * After confirming the account works, delete the SQL file.
 */

import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import * as readline from 'readline';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

// ── Configuration from env (non-secret values only) ──────────────────────────
const OWNER_FULL_NAME  = process.env.STAGING_OWNER_NAME    ?? 'RouteFlow Owner';
const COMPANY_NAME     = process.env.STAGING_COMPANY_NAME  ?? 'RouteFlow Demo';
// ─────────────────────────────────────────────────────────────────────────────

function prompt(rl: readline.Interface, question: string): Promise<string> {
  return new Promise(resolve => rl.question(question, resolve));
}

async function main() {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });

  // Read username interactively (not secret, but kept consistent with password flow)
  const username = (await prompt(rl, 'Staging owner username: ')).trim();
  if (!username) {
    console.error('ERROR: username is required.');
    rl.close();
    process.exit(1);
  }

  // Read password without echoing — use readline hack to suppress echo
  process.stdout.write('Staging owner password (min 16 chars, not echoed): ');
  const password = await new Promise<string>((resolve) => {
    let pass = '';
    const stdin = process.stdin;
    stdin.setRawMode?.(true);
    stdin.resume();
    stdin.setEncoding('utf8');
    const handler = (ch: string) => {
      if (ch === '\n' || ch === '\r' || ch === '\u0004') {
        stdin.setRawMode?.(false);
        stdin.pause();
        stdin.removeListener('data', handler);
        process.stdout.write('\n');
        resolve(pass);
      } else if (ch === '\u0003') {
        process.stdout.write('\n');
        process.exit(1);
      } else {
        pass += ch;
      }
    };
    stdin.on('data', handler);
  });

  rl.close();

  if (password.length < 16) {
    console.error('ERROR: Password must be at least 16 characters.');
    process.exit(1);
  }

  // Hash locally — plaintext never leaves this process
  console.log('Hashing password (bcrypt rounds=12, this takes a moment)…');
  const salt  = bcrypt.genSaltSync(12);
  const hash  = bcrypt.hashSync(password, salt);

  const companyId = `comp_stg_${crypto.randomUUID().replace(/-/g,'').slice(0,12)}`;
  const userId    = `user_stg_own_${crypto.randomUUID().replace(/-/g,'').slice(0,8)}`;
  const now       = Date.now();

  // Build SQL — guards against duplicate owner via NOT EXISTS
  const sql = `-- Staging owner provisioning SQL (generated ${new Date().toISOString()})
-- Company : ${COMPANY_NAME.replace(/'/g,"''")}
-- Username: ${username.replace(/'/g,"''")}
-- Full Name: ${OWNER_FULL_NAME.replace(/'/g,"''")}
-- REVIEW this file before applying. Delete it immediately after.

-- 1. Create company (idempotent — skips if id already exists)
INSERT INTO companies (id, name, created_at)
SELECT '${companyId}', '${COMPANY_NAME.replace(/'/g,"''")}', ${now}
WHERE NOT EXISTS (SELECT 1 FROM companies WHERE id = '${companyId}');

-- 2. Create owner user (refuses if username already taken)
INSERT INTO users (id, company_id, username, password_hash, full_name, role, is_active, created_at)
SELECT '${userId}', '${companyId}', '${username.replace(/'/g,"''")}', '${hash}', '${OWNER_FULL_NAME.replace(/'/g,"''")}', 'OWNER', 1, ${now}
WHERE NOT EXISTS (SELECT 1 FROM users WHERE username = '${username.replace(/'/g,"''")}');

-- 3. Verify (run this after applying to confirm):
-- SELECT id, username, role, is_active FROM users WHERE company_id = '${companyId}';
`;

  // Write to a temp file outside the project directory
  const tmpFile = path.join(os.tmpdir(), `routeflow-staging-provision-${Date.now()}.sql`);
  fs.writeFileSync(tmpFile, sql, { encoding: 'utf8', mode: 0o600 });

  console.log('\n──────────────────────────────────────────────────────');
  console.log('SQL written to (review before applying):');
  console.log(tmpFile);
  console.log('\nContent preview (no passwords are included):');
  console.log(sql.split('\n').filter(l => !l.includes(hash)).join('\n'));
  console.log('──────────────────────────────────────────────────────');
  console.log('\nApply with:');
  console.log(`  npx wrangler d1 execute routeflow-db-staging \\`);
  console.log(`    --config backend/wrangler.staging.toml \\`);
  console.log(`    --remote --file "${tmpFile}"`);
  console.log('\nAfter confirming login works, delete the file:');
  console.log(`  Remove-Item "${tmpFile}"`);
}

main().catch(e => { console.error(e); process.exit(1); });
