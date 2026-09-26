from pathlib import Path
p=Path('backend/src/index.ts');s=p.read_text(encoding='utf-8')
s="import { dailyCycle } from './daily-cycle';\nimport { fieldCycle } from './field-cycle';\nimport { requestOtp } from './delivery-proof';\n"+s
s=s.replace("  ENABLE_TEST_FAILURE_INJECTION?: string;", "  ENABLE_TEST_FAILURE_INJECTION?: string;\n  SMS_MODE?: string;\n  SMS_GATEWAY_URL?: string;\n  SMS_GATEWAY_TOKEN?: string;")
a=s.index("app.post('/collections'");s=s[:a]+"app.route('/', dailyCycle(authMiddleware));\napp.route('/', fieldCycle(authMiddleware));\n\nexport default app;\n"
a=s.index("app.post('/visits'");b=s.index("app.get('/beats'",a);s=s[:a]+s[b:]
a=s.index("app.post('/shifts/start'");b=s.index("app.get('/team/status'",a);s=s[:a]+s[b:]
a=s.index("app.post('/orders/:id/request-otp'");b=s.index("app.post('/orders/:id/deliver'",a);s=s[:a]+"app.post('/orders/:id/request-otp', authMiddleware, requestOtp);\n\n"+s[b:]
a=s.index('  // Generate server-backed 6-digit delivery OTP');b=s.index('  for (const item of items as any[])',a);s=s[:a]+s[b:]
s=s.replace('otpGenerated: true','otpGenerated: false')
s=s.replace("if (c.req.header('X-Test-Fail-Invoice') === 'true')", "if (isFailureInjectionAllowed(c) && c.req.header('X-Test-Fail-Invoice') === 'true')")
# Assignment must be checked before a successful replay, including delivered orders.
a=s.index("app.post('/orders/:id/deliver'");b=s.index('// Check if server-backed OTP',a)
part=s[a:b];start=part.index('  // Delivery employee authorization');guard=part[start:];part=part[:start];at=part.index("  if (order.status === 'DELIVERED')");part=part[:at]+guard+'\n'+part[at:];s=s[:a]+part+s[b:]
s=s.replace("    if (otpRecord.is_used === 1)", "    if (!['SENT', ...(c.env.ENVIRONMENT === 'development' && c.env.SMS_MODE === 'simulated' ? ['SIMULATED'] : [])].includes(otpRecord.send_status)) {\n      return c.json({ error: 'Recipient messaging has not been acknowledged' }, 400);\n    }\n    if (otpRecord.is_used === 1)")
# Claim OTP in the same atomic batch as invoice/payment/stock transition. Trigger verifies race conditions.
s=s.replace("      c.env.DB.prepare('UPDATE delivery_otps SET is_used = 1, recipient_name = ? WHERE order_id = ?')", "      c.env.DB.prepare('UPDATE delivery_otps SET is_used = 1, recipient_name = ? WHERE order_id = ?')")
# Credit exposure must be checked in SQLite, not a read-before-write JS calculation.
a=s.index('  // Retailer credit limit validation');b=s.index('  // Fetch active company promotions',a)
s=s[:a]+"""  const override = body.creditOverridePaise ?? 0;
  const overrideReason = body.creditOverrideReason?.trim() || null;
  if (!Number.isSafeInteger(override) || override < 0 || override > 1000000000 || (override > 0 && (user.role !== 'OWNER' || !overrideReason))) {
    return c.json({ error: 'Credit override requires owner, bounded amount and reason' }, 403);
  }
"""+s[b:]
s=s.replace('updated_at, idempotency_key) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', 'updated_at, idempotency_key, credit_override_paise, credit_override_reason, credit_override_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)')
s=s.replace("now, now, idempotencyKey || null),", "now, now, idempotencyKey || null, override, overrideReason, override > 0 ? user.sub : null),")
s=s.replace('`Total: ${order.totalAmountPaise} paise`', '`Total: ${order.totalAmountPaise} paise; credit override: ${override}; reason: ${overrideReason || "none"}`')
# Order idempotency cannot bypass a newly revoked retailer assignment.
a=s.index('  // Idempotency check: bound');b=s.index('  // Validate retailer and tenant isolation',a);idem=s[a:b];s=s[:a]+s[b:];at=s.index('  const override =');s=s[:at]+idem+s[at:]
# Rejection releases actual reservation at transition time in a trigger; avoids approval-vs-rejection stale read.
a=s.index('  // If order was previously APPROVED');b=s.index('  try {',a);s=s[:a]+s[b:]
# Error for exhausted credit remains a meaningful validation failure.
s=s.replace("    const isStale = lastLoc ? (now - lastLoc.timestamp > 1800000) : true;", "    const isStale = lastLoc ? (now - lastLoc.timestamp > 120000) : true;")
s=s.replace("shiftStatus: shift?.status === 'ON_SHIFT' ? 'ON_SHIFT' : 'OFF_SHIFT'", "shiftStatus: shift?.status || 'OFF_SHIFT'")
p.write_text(s,encoding='utf-8')
