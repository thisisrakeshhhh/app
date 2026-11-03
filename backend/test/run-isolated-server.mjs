import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { build } from 'esbuild';
import { readFile, readdir } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';

const bundle = await build({
  entryPoints: ['src/index.ts'],
  bundle: true,
  write: false,
  format: 'esm',
  platform: 'browser',
  target: 'es2022'
});

const mf = new Miniflare(convertV4MiniflareOptions({
  modules: true,
  script: bundle.outputFiles[0].text,
  compatibilityDate: '2024-03-20',
  d1Databases: ['DB'],
  bindings: {
    JWT_SECRET: 'isolated-test-secret-not-for-deployment',
    JWT_ACCESS_EXPIRY: '86400',
    JWT_REFRESH_EXPIRY: '2592000',
    ENVIRONMENT: 'development',
    ENABLE_TEST_FAILURE_INJECTION: 'true',
    SMS_MODE: 'simulated'
  },
  port: 0
}));

try {
  const db = await mf.getD1Database('DB');
  async function sql(path) {
    const source = await readFile(path, 'utf8');
    const split = spawnSync('python', ['-c', `import sys,sqlite3,json
s=sys.stdin.read(); parts=[]; current=''
for ch in s:
 current+=ch
 if ch==';' and sqlite3.complete_statement(current):
  parts.append(current);current=''
print(json.dumps(parts))`], { input: source, encoding: 'utf8' });
    if (split.status !== 0) throw new Error(split.stderr);
    const statements = JSON.parse(split.stdout);
    await db.batch(statements.map(s => db.prepare(s)));
  }

  for (const file of (await readdir('migrations')).filter(x => x.endsWith('.sql')).sort()) {
    if (file.startsWith('0007')) await sql('seeds/dev_seeds.sql');
    await sql(`migrations/${file}`);
  }

  const url = (await mf.ready).toString().replace(/\/$/, '');
  console.log(`SERVER_READY: ${url}`);

  // Keep alive until killed or stdin closes
  process.stdin.resume();
  await new Promise((resolve) => {
    process.stdin.on('end', resolve);
    process.on('SIGINT', resolve);
    process.on('SIGTERM', resolve);
  });
} finally {
  await mf.dispose();
}
