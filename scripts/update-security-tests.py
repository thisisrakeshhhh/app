from pathlib import Path
import re

p = Path('backend/test/integration.test.mjs')
s = p.read_text(encoding='utf-8')
# Exact original event, including optional fields, must be resent on retry.
s = s.replace("checkInTime: now - 900000,\n        idempotencyKey: `idemp_${visitId}`", "checkInTime: now - 900000,\n        checkOutTime: now,\n        latitude: 26.8521,\n        longitude: 75.7645,\n        accuracy: 8.5,\n        durationSeconds: 900,\n        status: 'COMPLETED',\n        notes: 'Owner verified stock, placed weekly order',\n        idempotencyKey: `idemp_${visitId}`")
s = s.replace("receiptId: 'REC-TEST-001',\n        idempotencyKey: testIdempotencyKey", "receiptId: 'REC-TEST-001',\n        notes: 'Partial collection by salesperson',\n        idempotencyKey: testIdempotencyKey")
pattern = r"(await fetch\(`\$\{BASE_URL\}/(?:returns|handovers/request|owner/handovers|stock-checks)[^`]*`, \{)(.*?)(\n    \}\);)"
def add_key(m):
    content = m[2]
    if 'body: JSON.stringify({' in content and 'idempotencyKey:' not in content:
        content = content.replace('body: JSON.stringify({', 'body: JSON.stringify({ idempotencyKey: crypto.randomUUID(),', 1)
    return m[1] + content + m[3]
s = re.sub(pattern, add_key, s, flags=re.S)
s = s.replace("assert.match(otpData.message, /Delivery OTP sent via SMS/)", "assert.match(otpData.message, /no SMS sent/)")
# Handle the equivalent existing assert.ok form.
s = s.replace("otpData.message.includes('Delivery OTP sent via SMS')", "otpData.message.includes('no SMS sent')")
p.write_text(s, encoding='utf-8')
