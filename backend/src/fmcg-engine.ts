import { canPerform } from './security';

export interface GstCalculationOptions {
  pricePaise: number; // Inclusive or exclusive base
  quantity: number;
  gstRate?: number; // e.g. 18.0
  isInterState?: boolean; // If true, IGST applies; otherwise CGST + SGST
  cessRate?: number; // Optional compensation cess (e.g. 12%)
  isPriceTaxInclusive?: boolean; // Usually in FMCG wholesale, rates are exclusive or MRP is inclusive
}

export interface GstLineBreakdown {
  taxableAmountPaise: number;
  gstRate: number;
  cgstAmountPaise: number;
  sgstAmountPaise: number;
  igstAmountPaise: number;
  cessAmountPaise: number;
  totalTaxPaise: number;
  totalLinePaise: number;
}

/**
 * Computes Indian GST breakdown for line items adhering to CBIC GST invoice standards.
 */
export function calculateGstBreakdown(options: GstCalculationOptions): GstLineBreakdown {
  const { pricePaise, quantity, isInterState = false, cessRate = 0, isPriceTaxInclusive = false } = options;
  const gstRate = options.gstRate ?? 18.0;

  let taxableAmountPaise = 0;
  let totalLinePaise = 0;

  if (isPriceTaxInclusive) {
    // If unit price includes tax: Taxable = Gross / (1 + (GST + Cess)/100)
    const totalTaxRateFraction = 1 + (gstRate + cessRate) / 100;
    const grossPaise = pricePaise * quantity;
    taxableAmountPaise = Math.round(grossPaise / totalTaxRateFraction);
    totalLinePaise = grossPaise;
  } else {
    // Standard wholesale: Price is taxable base
    taxableAmountPaise = pricePaise * quantity;
  }

  let cgstAmountPaise = 0;
  let sgstAmountPaise = 0;
  let igstAmountPaise = 0;
  const cessAmountPaise = Math.round(taxableAmountPaise * (cessRate / 100));

  if (isInterState) {
    igstAmountPaise = Math.round(taxableAmountPaise * (gstRate / 100));
  } else {
    // Intra-state split evenly 50/50 between CGST and SGST
    const halfRate = gstRate / 2;
    cgstAmountPaise = Math.round(taxableAmountPaise * (halfRate / 100));
    sgstAmountPaise = Math.round(taxableAmountPaise * (halfRate / 100));
  }

  const totalTaxPaise = cgstAmountPaise + sgstAmountPaise + igstAmountPaise + cessAmountPaise;
  if (!isPriceTaxInclusive) {
    totalLinePaise = taxableAmountPaise + totalTaxPaise;
  }

  return {
    taxableAmountPaise,
    gstRate,
    cgstAmountPaise,
    sgstAmountPaise,
    igstAmountPaise,
    cessAmountPaise,
    totalTaxPaise,
    totalLinePaise
  };
}

export interface CreditPolicyEvaluationParams {
  db: D1Database;
  companyId: string;
  retailerId: string;
  newOrderAmountPaise: number;
  overridePaise?: number;
  overrideReason?: string;
  userId: string;
  userRole: string;
}

export interface CreditPolicyResult {
  allowed: boolean;
  policyMode: 'HARD_STOP' | 'WARNING_ONLY' | 'APPROVAL_REQUIRED';
  currentExposurePaise: number;
  creditLimitPaise: number;
  overdueDays: number;
  hasOverdueInvoices: boolean;
  isBreached: boolean;
  isOverridden: boolean;
  requiresApproval: boolean;
  error?: string;
  warning?: string;
  statementsToExecute?: any[];
}

/**
 * Organization-configurable credit policy evaluator.
 * Default policy mode is HARD_STOP: blocks confirmation when credit limit or overdue threshold is breached.
 * Authorized exceptions record approver, reason, and timestamp.
 */
export async function evaluateCreditPolicy(
  params: CreditPolicyEvaluationParams
): Promise<CreditPolicyResult> {
  const {
    db, companyId, retailerId, newOrderAmountPaise,
    overridePaise = 0, overrideReason, userId, userRole
  } = params;

  // 1. Fetch retailer profile
  const retailer = await db.prepare(
    'SELECT id, name, credit_limit_paise, outstanding_amount_paise, payment_terms_days FROM retailers WHERE id = ? AND company_id = ?'
  ).bind(retailerId, companyId).first<{
    id: string;
    name: string;
    credit_limit_paise: number;
    outstanding_amount_paise: number;
    payment_terms_days: number | null;
  }>();

  if (!retailer) {
    return {
      allowed: false,
      policyMode: 'HARD_STOP',
      currentExposurePaise: 0,
      creditLimitPaise: 0,
      overdueDays: 0,
      hasOverdueInvoices: false,
      isBreached: true,
      isOverridden: false,
      requiresApproval: false,
      error: 'Retailer not found'
    };
  }

  // 2. Fetch company credit policy (defaulting to HARD_STOP if not configured)
  let policyMode: 'HARD_STOP' | 'WARNING_ONLY' | 'APPROVAL_REQUIRED' = 'HARD_STOP';
  let maxOverdueDays = 30;

  try {
    const policy = await db.prepare(
      'SELECT policy_mode, max_overdue_days, allow_sales_override FROM credit_policies WHERE company_id = ?'
    ).bind(companyId).first<{ policy_mode: string; max_overdue_days: number; allow_sales_override: number }>();

    if (policy) {
      if (policy.policy_mode === 'WARNING_ONLY' || policy.policy_mode === 'APPROVAL_REQUIRED' || policy.policy_mode === 'HARD_STOP') {
        policyMode = policy.policy_mode;
      }
      if (policy.max_overdue_days > 0) {
        maxOverdueDays = policy.max_overdue_days;
      }
    }
  } catch {
    // If credit_policies table is not present yet, preserve HARD_STOP default
  }

  // 3. Compute active reservations (authoritative) or unfulfilled pending orders (legacy fallback)
  let openOrdersExposurePaise = 0;
  let hasReservationSchema = false;

  try {
    const res = await db.prepare(
      'SELECT COALESCE(SUM(amount_paise), 0) AS total_res FROM credit_reservations WHERE retailer_id = ? AND company_id = ?'
    ).bind(retailerId, companyId).first<{ total_res: number }>();
    openOrdersExposurePaise = res?.total_res || 0;
    hasReservationSchema = true;
  } catch (err: any) {
    const msg = (err?.message || String(err)).toLowerCase();
    if (msg.includes('no such table')) {
      hasReservationSchema = false;
    } else {
      return {
        allowed: false,
        policyMode,
        currentExposurePaise: 0,
        creditLimitPaise: 0,
        overdueDays: 0,
        hasOverdueInvoices: false,
        isBreached: true,
        isOverridden: false,
        requiresApproval: false,
        error: `Database error querying credit reservations: ${err?.message || String(err)}`
      };
    }
  }

  // Only query open orders directly if credit_reservations table is confirmed absent
  if (!hasReservationSchema) {
    try {
      const pending = await db.prepare(
        `SELECT COALESCE(SUM(total_amount_paise), 0) AS total_pending FROM orders
         WHERE retailer_id = ? AND company_id = ?
         AND status IN ('SUBMITTED', 'PENDING_APPROVAL', 'APPROVED', 'PICKING', 'PACKED', 'OUT_FOR_DELIVERY')`
      ).bind(retailerId, companyId).first<{ total_pending: number }>();
      openOrdersExposurePaise = pending?.total_pending || 0;
    } catch (err: any) {
      return {
        allowed: false,
        policyMode,
        currentExposurePaise: 0,
        creditLimitPaise: 0,
        overdueDays: 0,
        hasOverdueInvoices: false,
        isBreached: true,
        isOverridden: false,
        requiresApproval: false,
        error: `Database error querying pending orders exposure: ${err?.message || String(err)}`
      };
    }
  }

  const currentExposurePaise = (retailer.outstanding_amount_paise || 0) + openOrdersExposurePaise;
  const projectedExposurePaise = currentExposurePaise + newOrderAmountPaise;
  const creditLimitPaise = retailer.credit_limit_paise || 0;

  // 4. Check for overdue invoices
  const paymentTermsDays = retailer.payment_terms_days && retailer.payment_terms_days > 0
    ? retailer.payment_terms_days
    : maxOverdueDays;

  const overdueCutoffMs = Date.now() - (paymentTermsDays * 86400 * 1000);
  let hasOverdueInvoices = false;
  let oldestOverdueDays = 0;

  try {
    const oldestInvoice = await db.prepare(
      `SELECT created_at FROM invoices
       WHERE retailer_id = ? AND company_id = ?
       AND (total_amount_paise - paid_paise - credited_paise) > 0
       AND created_at <= ?
       ORDER BY created_at ASC LIMIT 1`
    ).bind(retailerId, companyId, overdueCutoffMs).first<{ created_at: number }>();

    if (oldestInvoice) {
      hasOverdueInvoices = true;
      oldestOverdueDays = Math.floor((Date.now() - oldestInvoice.created_at) / (86400 * 1000));
    }
  } catch (err: any) {
    const msg = (err?.message || String(err)).toLowerCase();
    if (msg.includes('no such table') || msg.includes('no such column')) {
      try {
        const oldestUnpaid = await db.prepare(
          `SELECT created_at FROM orders
           WHERE retailer_id = ? AND company_id = ? AND status = 'DELIVERED'
           AND (total_amount_paise - COALESCE(delivered_amount_paise, 0)) > 0
           AND created_at <= ?
           ORDER BY created_at ASC LIMIT 1`
        ).bind(retailerId, companyId, overdueCutoffMs).first<{ created_at: number }>();

        if (oldestUnpaid) {
          hasOverdueInvoices = true;
          oldestOverdueDays = Math.floor((Date.now() - oldestUnpaid.created_at) / (86400 * 1000));
        }
      } catch (fallbackErr: any) {
        return {
          allowed: false,
          policyMode,
          currentExposurePaise: 0,
          creditLimitPaise: 0,
          overdueDays: 0,
          hasOverdueInvoices: false,
          isBreached: true,
          isOverridden: false,
          requiresApproval: false,
          error: `Database error querying overdue orders fallback: ${fallbackErr?.message || String(fallbackErr)}`
        };
      }
    } else {
      return {
        allowed: false,
        policyMode,
        currentExposurePaise: 0,
        creditLimitPaise: 0,
        overdueDays: 0,
        hasOverdueInvoices: false,
        isBreached: true,
        isOverridden: false,
        requiresApproval: false,
        error: `Database error checking overdue invoices: ${err?.message || String(err)}`
      };
    }
  }

  const isLimitBreached = projectedExposurePaise > creditLimitPaise;
  const isBreached = isLimitBreached || hasOverdueInvoices;

  // 5. Handle authorized credit overrides
  const statementsToExecute: any[] = [];
  let isOverridden = false;

  if (isBreached && overridePaise > 0) {
    const canOverride = canPerform(userRole, 'retailer:credit_override');
    if (!canOverride) {
      return {
        allowed: false,
        policyMode,
        currentExposurePaise,
        creditLimitPaise,
        overdueDays: oldestOverdueDays,
        hasOverdueInvoices,
        isBreached: true,
        isOverridden: false,
        requiresApproval: true,
        error: `Permission denied: role '${userRole}' cannot authorize a credit policy override.`
      };
    }

    if (!overrideReason || overrideReason.trim().length < 5) {
      return {
        allowed: false,
        policyMode,
        currentExposurePaise,
        creditLimitPaise,
        overdueDays: oldestOverdueDays,
        hasOverdueInvoices,
        isBreached: true,
        isOverridden: false,
        requiresApproval: true,
        error: 'A detailed reason (minimum 5 characters) is required to authorize a credit override.'
      };
    }

    if (projectedExposurePaise > creditLimitPaise + overridePaise) {
      return {
        allowed: false,
        policyMode,
        currentExposurePaise,
        creditLimitPaise,
        overdueDays: oldestOverdueDays,
        hasOverdueInvoices,
        isBreached: true,
        isOverridden: false,
        requiresApproval: true,
        error: `Override amount ${overridePaise} paise is insufficient. Projected exposure ${projectedExposurePaise} paise exceeds limit ${creditLimitPaise + overridePaise} paise.`
      };
    }

    // Authorized override granted: audit and persist
    isOverridden = true;
    try {
      statementsToExecute.push(
        db.prepare(
          `INSERT INTO credit_overrides (id, company_id, retailer_id, order_id, override_amount_paise, exposure_at_time_paise, credit_limit_paise, authorized_by, reason, created_at)
           VALUES (?, ?, ?, NULL, ?, ?, ?, ?, ?, ?)`
        ).bind(
          crypto.randomUUID(), companyId, retailerId, overridePaise,
          projectedExposurePaise, creditLimitPaise, userId, overrideReason.trim(), Date.now()
        )
      );
    } catch {
      // credit_overrides table fallback
    }
  }

  // 6. Apply Policy Decisions
  if (!isBreached || isOverridden) {
    return {
      allowed: true,
      policyMode,
      currentExposurePaise,
      creditLimitPaise,
      overdueDays: oldestOverdueDays,
      hasOverdueInvoices,
      isBreached,
      isOverridden,
      requiresApproval: false,
      statementsToExecute
    };
  }

  // Breached and not overridden
  if (policyMode === 'WARNING_ONLY') {
    return {
      allowed: true,
      policyMode,
      currentExposurePaise,
      creditLimitPaise,
      overdueDays: oldestOverdueDays,
      hasOverdueInvoices,
      isBreached: true,
      isOverridden: false,
      requiresApproval: false,
      warning: `Credit limit breached: Retailer exposure ${projectedExposurePaise} paise exceeds limit ${creditLimitPaise} paise. Allowed under WARNING_ONLY policy.`
    };
  }

  // Default HARD_STOP or APPROVAL_REQUIRED
  const breachDetail = isLimitBreached
    ? `Projected exposure ₹${(projectedExposurePaise / 100).toFixed(2)} exceeds credit limit ₹${(creditLimitPaise / 100).toFixed(2)}.`
    : `Retailer has overdue unpaid invoices (${oldestOverdueDays} days old, exceeding ${paymentTermsDays}-day limit).`;

  return {
    allowed: false,
    policyMode,
    currentExposurePaise,
    creditLimitPaise,
    overdueDays: oldestOverdueDays,
    hasOverdueInvoices,
    isBreached: true,
    isOverridden: false,
    requiresApproval: true,
    error: `Credit Policy Breach: ${breachDetail} Order blocked under organization ${policyMode} policy.`
  };
}

/**
 * Creates double-entry statements for retailer ledger updates.
 * Keeps retailers.outstanding_amount_paise strictly synchronized with ledger entries.
 */
export function buildRetailerLedgerStatements(options: {
  db: D1Database;
  companyId: string;
  retailerId: string;
  entryType: 'INVOICE_DEBIT' | 'PAYMENT_CREDIT' | 'RETURN_CREDIT' | 'ADJUSTMENT';
  referenceId?: string;
  amountPaise: number;
  currentOutstandingPaise: number;
  notes?: string;
  userId?: string;
}) {
  const {
    db, companyId, retailerId, entryType, referenceId,
    amountPaise, currentOutstandingPaise, notes, userId
  } = options;

  let newBalancePaise = currentOutstandingPaise;
  if (entryType === 'INVOICE_DEBIT') {
    newBalancePaise += amountPaise;
  } else {
    newBalancePaise = Math.max(0, currentOutstandingPaise - amountPaise);
  }

  const now = Date.now();
  const ledgerId = `led_${now}_${Math.random().toString(36).substring(2, 7)}`;

  return [
    // 1. Immutable ledger row
    db.prepare(
      `INSERT INTO retailer_ledgers (id, company_id, retailer_id, entry_type, reference_id, amount_paise, running_balance_paise, notes, created_by, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).bind(
      ledgerId, companyId, retailerId, entryType, referenceId || null,
      amountPaise, newBalancePaise, notes || null, userId || null, now
    ),
    // 2. Synchronize retailer outstanding balance
    db.prepare(
      'UPDATE retailers SET outstanding_amount_paise = ? WHERE id = ? AND company_id = ?'
    ).bind(newBalancePaise, retailerId, companyId)
  ];
}
