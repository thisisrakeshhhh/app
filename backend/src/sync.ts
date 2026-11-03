import { Hono } from 'hono';
import { normalizeRole, canPerform } from './security';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
};

type Variables = {
  user: {
    sub: string;
    sid: string;
    company_id: string;
    role: string;
    name: string;
  };
};

async function sha256Hex(data: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(data));
  return Array.from(new Uint8Array(digest)).map(b => b.toString(16).padStart(2, '0')).join('');
}

export function syncRouter(authMiddleware: any) {
  const router = new Hono<{ Bindings: Bindings; Variables: Variables }>();

  router.use('*', authMiddleware);

  // --------------------------------------------------------------------------
  // POST /sync/push — Chronological Batch Processing of Outbox Mutations
  // --------------------------------------------------------------------------
  router.post('/sync/push', async (c) => {
    const user = c.get('user');
    const userRole = normalizeRole(user.role);
    const tenantId = user.company_id;

    let body: any;
    try {
      body = await c.req.json();
    } catch {
      return c.json({ success: false, error: 'INVALID_JSON', message: 'Request body must be valid JSON' }, 400);
    }

    const { clientBatchId, organizationId, userId, mutations } = body || {};

    // 1. Strict Multi-Tenant Isolation
    if (organizationId && organizationId !== tenantId) {
      return c.json({
        success: false,
        error: 'TENANT_MISMATCH',
        message: `Cross-tenant violation: requested organizationId '${organizationId}' does not match authenticated tenant '${tenantId}'`
      }, 403);
    }

    if (userId && userId !== user.sub) {
      return c.json({
        success: false,
        error: 'USER_MISMATCH',
        message: `User identity violation: requested userId '${userId}' does not match token subject '${user.sub}'`
      }, 403);
    }

    if (!Array.isArray(mutations) || mutations.length === 0) {
      return c.json({ success: false, error: 'EMPTY_BATCH', message: 'mutations array is required and must not be empty' }, 400);
    }

    // 2. Fetch current maximum server sequence order for this tenant
    const maxSeqRow = await c.env.DB.prepare(
      'SELECT MAX(server_sequence_order) as maxSeq FROM server_outbox_audit WHERE organization_id = ?'
    ).bind(tenantId).first<{ maxSeq: number | null }>();

    let currentSeq = maxSeqRow?.maxSeq ?? 0;
    const results: any[] = [];
    const provisionalToRealRetailerId = new Map<string, string>();

    // 3. Process each mutation in strict order
    for (const m of mutations) {
      const {
        mutationId,
        sequenceOrder,
        idempotencyKey,
        mutationType,
        provisionalBusinessId,
        payload
      } = m || {};

      if (!idempotencyKey || !mutationType) {
        return c.json({ success: false, error: 'INVALID_MUTATION', message: 'idempotencyKey and mutationType are required' }, 400);
      }

      // Canonical payload hash
      const payloadString = JSON.stringify(payload ?? {});
      const payloadHash = await sha256Hex(payloadString);

      // Check idempotency table
      const existingAudit = await c.env.DB.prepare(
        'SELECT * FROM server_outbox_audit WHERE organization_id = ? AND idempotency_key = ?'
      ).bind(tenantId, idempotencyKey).first<any>();

      if (existingAudit) {
        if (existingAudit.payload_hash !== payloadHash) {
          // Idempotency payload mismatch -> Fail closed with 409 Conflict
          return c.json({
            success: false,
            error: 'IDEMPOTENCY_PAYLOAD_MISMATCH',
            mutationId,
            message: `Idempotency key ${idempotencyKey} was previously registered with a different payload snapshot.`
          }, 409);
        }

        // Exact match -> return cached result
        results.push({
          mutationId,
          status: 'COMMITTED',
          provisionalBusinessId: existingAudit.provisional_business_id,
          serverBusinessId: existingAudit.server_business_id,
          serverSequence: existingAudit.server_sequence_order,
          cached: true
        });
        if (existingAudit.provisional_business_id && existingAudit.server_business_id) {
          provisionalToRealRetailerId.set(existingAudit.provisional_business_id, existingAudit.server_business_id);
        }
        continue;
      }

      // 4. Role-Based Access Control (RBAC) Server Enforcement
      if (mutationType === 'CREATE_RETAILER') {
        const reqClass = (payload?.classification || 'NEW').trim();
        const reqCreditLimit = Number(payload?.defaultCreditLimitPaise || 0);

        if (userRole === 'SALES') {
          if (reqClass !== 'NEW' || reqCreditLimit > 0) {
            return c.json({
              success: false,
              error: 'FORBIDDEN_ROLE_ACTION',
              message: 'Salesperson can only create shops with class NEW and credit limit 0 paise'
            }, 403);
          }
        } else if (userRole !== 'OWNER' && userRole !== 'ADMIN') {
          return c.json({
            success: false,
            error: 'FORBIDDEN_ROLE_ACTION',
            message: `Role '${userRole}' is not authorized to create retailers`
          }, 403);
        }

        const serverId = `ret_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
        const nowMs = Date.now();
        const shopName = payload?.shopName || payload?.name || 'Unnamed Shop';
        const contactNumber = payload?.phone || payload?.contactNumber || '';
        const address = payload?.address || '';
        const beatId = payload?.route || payload?.beatId || 'DEFAULT_BEAT';
        const lat = payload?.latitude ?? null;
        const lng = payload?.longitude ?? null;
        const gstin = payload?.gstin ?? null;
        const ownerName = payload?.ownerName ?? null;

        currentSeq++;

        // Atomic insertion of retailer + audit log
        await c.env.DB.batch([
          c.env.DB.prepare(
            `INSERT INTO retailers (id, company_id, name, beat_id, address, contact_number, latitude, longitude, credit_limit_paise, outstanding_amount_paise, is_active, payment_terms_days, classification, gstin, owner_name)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 1, 0, ?, ?, ?)`
          ).bind(serverId, tenantId, shopName, beatId, address, contactNumber, lat, lng, reqCreditLimit, reqClass, gstin, ownerName),

          c.env.DB.prepare(
            `INSERT INTO server_outbox_audit (id, organization_id, user_id, idempotency_key, mutation_type, payload_hash, payload_json, provisional_business_id, server_business_id, client_sequence_order, server_sequence_order, processed_at_epoch_ms)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
          ).bind(
            `audit_${nowMs}_${currentSeq}`,
            tenantId,
            user.sub,
            idempotencyKey,
            mutationType,
            payloadHash,
            payloadString,
            provisionalBusinessId || null,
            serverId,
            sequenceOrder || 0,
            currentSeq,
            nowMs
          )
        ]);

        if (provisionalBusinessId) {
          provisionalToRealRetailerId.set(provisionalBusinessId, serverId);
        }

        results.push({
          mutationId,
          status: 'COMMITTED',
          provisionalBusinessId,
          serverBusinessId: serverId,
          serverSequence: currentSeq
        });

      } else if (mutationType === 'CREATE_ORDER') {
        if (userRole === 'WAREHOUSE' || userRole === 'DELIVERY') {
          return c.json({
            success: false,
            error: 'FORBIDDEN_ROLE_ACTION',
            message: `Role '${userRole}' is not authorized to create orders`
          }, 403);
        }

        let retailerId = payload?.retailerId || payload?.retailer?.id;
        if (provisionalToRealRetailerId.has(retailerId)) {
          retailerId = provisionalToRealRetailerId.get(retailerId);
        }

        // Verify retailer belongs to current tenant
        const retailer = await c.env.DB.prepare(
          'SELECT id, name, classification, credit_limit_paise, outstanding_amount_paise FROM retailers WHERE id = ? AND company_id = ?'
        ).bind(retailerId, tenantId).first<any>();

        if (!retailer) {
          return c.json({
            success: false,
            error: 'RETAILER_NOT_FOUND',
            message: `Retailer '${retailerId}' does not exist in organization '${tenantId}'`
          }, 400);
        }

        const items = payload?.items || [];
        if (!Array.isArray(items) || items.length === 0) {
          return c.json({ success: false, error: 'EMPTY_ORDER', message: 'Order must contain at least 1 item' }, 400);
        }

        // Server-Side Price & Tax Recalculation + Overselling Stock Check
        let serverTaxablePaise = 0;
        let serverGstPaise = 0;
        let serverTotalAmountPaise = 0;
        const verifiedLines: any[] = [];
        const stockReservationStatements: D1PreparedStatement[] = [];

        for (const item of items) {
          const prod = await c.env.DB.prepare(
            'SELECT id, name, price_paise, stock_quantity, reserved_quantity FROM products WHERE id = ? AND company_id = ?'
          ).bind(item.productId, tenantId).first<any>();

          if (!prod) {
            return c.json({
              success: false,
              error: 'PRODUCT_NOT_FOUND',
              message: `Product '${item.productId}' not found in catalog`
            }, 400);
          }

          const unitName = (item.orderedUnit || item.unit || 'piece').toLowerCase().trim();
          const unitDef = await c.env.DB.prepare(
            'SELECT multiplier_to_base, price_paise, can_sell FROM product_units WHERE organization_id = ? AND product_id = ? AND unit_name = ?'
          ).bind(tenantId, prod.id, unitName).first<{ multiplier_to_base: number; price_paise: number; can_sell: number }>();

          let effectiveMultiplier: number;
          let unitPricePaise = prod.price_paise;

          if (unitDef) {
            if (unitDef.can_sell === 0) {
              return c.json({
                success: false,
                error: 'UNIT_NOT_SALEABLE',
                message: `Unit '${unitName}' for product '${prod.name}' is not allowed for sale`
              }, 400);
            }
            effectiveMultiplier = unitDef.multiplier_to_base;
            if (unitDef.price_paise > 0) {
              unitPricePaise = unitDef.price_paise;
            }
            // Strict verification against client tampering
            if (item.multiplierToBaseAtTime !== undefined && Number(item.multiplierToBaseAtTime) !== effectiveMultiplier) {
              return c.json({
                success: false,
                error: 'INVALID_UNIT_MULTIPLIER',
                message: `Unit multiplier mismatch: client claims ${item.multiplierToBaseAtTime} for '${unitName}', but server master defines ${effectiveMultiplier}`
              }, 400);
            }
          } else {
            if (unitName === 'box' || unitName === 'crate') {
              if (!item.multiplierToBaseAtTime || Number(item.multiplierToBaseAtTime) <= 1) {
                return c.json({
                  success: false,
                  error: 'INVALID_UNIT_MULTIPLIER',
                  message: `Unit '${unitName}' requires server packaging definition and cannot have multiplier <= 1`
                }, 400);
              }
              effectiveMultiplier = Number(item.multiplierToBaseAtTime);
            } else {
              effectiveMultiplier = 1;
            }
          }

          const availablePieces = prod.stock_quantity - prod.reserved_quantity;
          const totalPiecesRequired = Number(item.orderedQuantity) * effectiveMultiplier;

          // Overselling Protection Invariant
          if (totalPiecesRequired > availablePieces) {
            return c.json({
              success: false,
              error: 'INSUFFICIENT_STOCK',
              message: `Overselling protection: product '${prod.name}' has only ${availablePieces} available pieces, requested ${totalPiecesRequired}`
            }, 400);
          }

          // Data-driven price from master or verified line unit price
          const lineTotalPaise = Number(item.orderedQuantity) * unitPricePaise;
          const gstRate = Number(item.gstRate ?? 5.0);
          const taxablePaise = Math.round((lineTotalPaise * 10000) / (10000 + Math.round(gstRate * 100)));
          const gstAmountPaise = lineTotalPaise - taxablePaise;

          serverTaxablePaise += taxablePaise;
          serverGstPaise += gstAmountPaise;
          serverTotalAmountPaise += lineTotalPaise;

          verifiedLines.push({
            productId: prod.id,
            orderedQuantity: Number(item.orderedQuantity),
            unitPricePaise,
            lineTotalPaise,
            totalPiecesRequired
          });

          // Atomic stock reservation
          stockReservationStatements.push(
            c.env.DB.prepare(
              'UPDATE products SET reserved_quantity = reserved_quantity + ? WHERE id = ? AND company_id = ?'
            ).bind(totalPiecesRequired, prod.id, tenantId)
          );
        }

        const orderId = `ord_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
        const nowMs = Date.now();
        currentSeq++;

        // Batch execution: Order + Order Items + Stock Reservations + Outbox Audit
        const batchStatements: D1PreparedStatement[] = [
          c.env.DB.prepare(
            `INSERT INTO orders (id, company_id, retailer_id, employee_id, status, total_amount_paise, created_at, updated_at, idempotency_key)
             VALUES (?, ?, ?, ?, 'CONFIRMED', ?, ?, ?, ?)`
          ).bind(orderId, tenantId, retailerId, user.sub, serverTotalAmountPaise, Math.floor(nowMs / 1000), Math.floor(nowMs / 1000), idempotencyKey),

          ...verifiedLines.map(l =>
            c.env.DB.prepare(
              `INSERT INTO order_items (id, order_id, product_id, quantity, free_quantity, price_paise_at_time, is_picked)
               VALUES (?, ?, ?, ?, 0, ?, 0)`
            ).bind(`item_${nowMs}_${Math.random().toString(36).substring(2, 6)}`, orderId, l.productId, l.orderedQuantity, l.unitPricePaise)
          ),

          ...stockReservationStatements,

          c.env.DB.prepare(
            `INSERT INTO server_outbox_audit (id, organization_id, user_id, idempotency_key, mutation_type, payload_hash, payload_json, provisional_business_id, server_business_id, client_sequence_order, server_sequence_order, processed_at_epoch_ms)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
          ).bind(
            `audit_${nowMs}_${currentSeq}`,
            tenantId,
            user.sub,
            idempotencyKey,
            mutationType,
            payloadHash,
            payloadString,
            provisionalBusinessId || null,
            orderId,
            sequenceOrder || 0,
            currentSeq,
            nowMs
          )
        ];

        try {
          await c.env.DB.batch(batchStatements);
        } catch (e: any) {
          const msg = e?.message || String(e);
          if (msg.includes('INSUFFICIENT_STOCK')) {
            return c.json({
              success: false,
              error: 'INSUFFICIENT_STOCK',
              message: 'Overselling protection: insufficient available stock to satisfy order reservation across all lines'
            }, 400);
          }
          throw e;
        }

        results.push({
          mutationId,
          status: 'COMMITTED',
          provisionalBusinessId,
          serverBusinessId: orderId,
          serverSequence: currentSeq,
          serverCalculatedTotals: {
            totalAmountPaise: serverTotalAmountPaise,
            taxableAmountPaise: serverTaxablePaise,
            gstAmountPaise: serverGstPaise
          }
        });

      } else if (mutationType === 'RECEIVE_GRN') {
        if (userRole !== 'WAREHOUSE' && userRole !== 'OWNER' && userRole !== 'ADMIN') {
          return c.json({
            success: false,
            error: 'FORBIDDEN_ROLE_ACTION',
            message: `Role '${userRole}' is not authorized to receive GRN inventory`
          }, 403);
        }

        const items = payload?.items || [];
        const nowMs = Date.now();
        const grnId = `grn_${nowMs}_${Math.random().toString(36).substring(2, 6)}`;
        currentSeq++;

        const grnStatements: D1PreparedStatement[] = [];

        for (const it of items) {
          const pieces = Number(it.piecesReceived || it.looseQuantity || it.quantity || 0);
          if (pieces <= 0) continue;

          const prod = await c.env.DB.prepare(
            'SELECT stock_quantity FROM products WHERE id = ? AND company_id = ?'
          ).bind(it.productId, tenantId).first<{ stock_quantity: number }>();

          const stockBefore = prod?.stock_quantity ?? 0;
          const stockAfter = stockBefore + pieces;

          grnStatements.push(
            c.env.DB.prepare(
              'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ? AND company_id = ?'
            ).bind(pieces, it.productId, tenantId)
          );

          grnStatements.push(
            c.env.DB.prepare(
              `INSERT INTO stock_movements (id, company_id, product_id, batch_id, movement_type, quantity, stock_before, stock_after, reason, notes, created_by, created_at)
               VALUES (?, ?, ?, ?, 'INWARD_GRN', ?, ?, ?, 'INWARD_GRN', ?, ?, ?)`
            ).bind(
              `mov_${nowMs}_${Math.random().toString(36).substring(2, 6)}`,
              tenantId,
              it.productId,
              it.batchNumber || null,
              pieces,
              stockBefore,
              stockAfter,
              it.remarks || 'Sync Inward GRN',
              user.sub,
              Math.floor(nowMs / 1000)
            )
          );
        }

        grnStatements.push(
          c.env.DB.prepare(
            `INSERT INTO server_outbox_audit (id, organization_id, user_id, idempotency_key, mutation_type, payload_hash, payload_json, provisional_business_id, server_business_id, client_sequence_order, server_sequence_order, processed_at_epoch_ms)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
          ).bind(
            `audit_${nowMs}_${currentSeq}`,
            tenantId,
            user.sub,
            idempotencyKey,
            mutationType,
            payloadHash,
            payloadString,
            provisionalBusinessId || null,
            grnId,
            sequenceOrder || 0,
            currentSeq,
            nowMs
          )
        );

        if (grnStatements.length > 0) {
          await c.env.DB.batch(grnStatements);
        }

        results.push({
          mutationId,
          status: 'COMMITTED',
          provisionalBusinessId,
          serverBusinessId: grnId,
          serverSequence: currentSeq
        });

      } else if (mutationType === 'UPDATE_CLASS_SETTINGS') {
        if (userRole !== 'OWNER' && userRole !== 'ADMIN') {
          return c.json({
            success: false,
            error: 'FORBIDDEN_ROLE_ACTION',
            message: 'Only Distributor Owner can modify retailer class settings'
          }, 403);
        }

        const className = payload?.className;
        const defaultCreditLimitPaise = Number(payload?.defaultCreditLimitPaise || 0);
        const creditDays = Number(payload?.creditDays || 0);
        const visitFrequencyDays = Number(payload?.visitFrequencyDays || 7);
        const nowMs = Date.now();
        currentSeq++;

        await c.env.DB.batch([
          c.env.DB.prepare(
            `INSERT INTO retailer_class_settings (organization_id, class_name, default_credit_limit_paise, credit_days, visit_frequency_days, updated_at_epoch_ms)
             VALUES (?, ?, ?, ?, ?, ?)
             ON CONFLICT(organization_id, class_name) DO UPDATE SET
               default_credit_limit_paise = excluded.default_credit_limit_paise,
               credit_days = excluded.credit_days,
               visit_frequency_days = excluded.visit_frequency_days,
               updated_at_epoch_ms = excluded.updated_at_epoch_ms`
          ).bind(tenantId, className, defaultCreditLimitPaise, creditDays, visitFrequencyDays, nowMs),

          c.env.DB.prepare(
            `INSERT INTO server_outbox_audit (id, organization_id, user_id, idempotency_key, mutation_type, payload_hash, payload_json, provisional_business_id, server_business_id, client_sequence_order, server_sequence_order, processed_at_epoch_ms)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
          ).bind(
            `audit_${nowMs}_${currentSeq}`,
            tenantId,
            user.sub,
            idempotencyKey,
            mutationType,
            payloadHash,
            payloadString,
            provisionalBusinessId || null,
            className,
            sequenceOrder || 0,
            currentSeq,
            nowMs
          )
        ]);

        results.push({
          mutationId,
          status: 'COMMITTED',
          serverBusinessId: className,
          serverSequence: currentSeq
        });

      } else if (mutationType === 'CREATE_PRODUCT') {
        if (userRole !== 'OWNER' && userRole !== 'ADMIN') {
          return c.json({
            success: false,
            error: 'FORBIDDEN_ROLE_ACTION',
            message: 'Only Owner or Admin can create new products'
          }, 403);
        }

        const prodId = payload?.id || `prod_${Date.now()}`;
        const name = payload?.name?.trim();
        if (!name) {
          return c.json({ success: false, error: 'BAD_REQUEST', message: 'Product name is required' }, 400);
        }
        const hindiName = payload?.hindiName || name;
        const category = payload?.category || 'General';
        const pricePaise = Number(payload?.piecePricePaise || payload?.pricePaise || 0);
        const mrpPaise = Number(payload?.mrpPaise || (Number(payload?.mrpRupees || 0) * 100));
        const gstRate = Number(payload?.gstRate || 5.0);
        const units = payload?.units || [];
        const nowMs = Date.now();
        currentSeq++;

        const productStmts: D1PreparedStatement[] = [
          c.env.DB.prepare(
            `INSERT INTO products (id, company_id, name, hindi_name, category, price_paise, mrp_paise, gst_rate, stock_quantity, reserved_quantity, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?)`
          ).bind(prodId, tenantId, name, hindiName, category, pricePaise, mrpPaise, gstRate, Math.floor(nowMs / 1000), Math.floor(nowMs / 1000)),

          ...units.map((u: any) =>
            c.env.DB.prepare(
              `INSERT INTO product_units (id, organization_id, product_id, unit_name, multiplier_to_base, is_base_unit, allow_loose_sale, can_buy, can_sell, price_paise, mrp_paise, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
            ).bind(
              `punit_${nowMs}_${Math.random().toString(36).substring(2, 6)}`,
              tenantId,
              prodId,
              (u.unitName || 'piece').toLowerCase().trim(),
              Number(u.multiplierToBase || 1),
              Number(u.multiplierToBase) === 1 ? 1 : 0,
              u.allowLooseSale !== false ? 1 : 0,
              u.canBuy !== false ? 1 : 0,
              u.canSell !== false ? 1 : 0,
              Number(u.wholesalePricePaise || pricePaise),
              Number(u.mrpPaise || mrpPaise),
              nowMs
            )
          ),

          c.env.DB.prepare(
            `INSERT INTO server_outbox_audit (id, organization_id, user_id, idempotency_key, mutation_type, payload_hash, payload_json, provisional_business_id, server_business_id, client_sequence_order, server_sequence_order, processed_at_epoch_ms)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
          ).bind(
            `audit_${nowMs}_${currentSeq}`,
            tenantId,
            user.sub,
            idempotencyKey,
            mutationType,
            payloadHash,
            payloadString,
            provisionalBusinessId || null,
            prodId,
            sequenceOrder || 0,
            currentSeq,
            nowMs
          )
        ];

        await c.env.DB.batch(productStmts);

        results.push({
          mutationId,
          status: 'COMMITTED',
          provisionalBusinessId,
          serverBusinessId: prodId,
          serverSequence: currentSeq
        });

      } else if (mutationType === 'UPDATE_PRODUCT_UNITS') {
        if (userRole !== 'OWNER' && userRole !== 'ADMIN') {
          return c.json({
            success: false,
            error: 'FORBIDDEN_ROLE_ACTION',
            message: 'Only Owner or Admin can update product units'
          }, 403);
        }

        const prodId = payload?.productId;
        const units = payload?.units || [];
        const nowMs = Date.now();
        currentSeq++;

        const unitStmts: D1PreparedStatement[] = [
          c.env.DB.prepare('DELETE FROM product_units WHERE organization_id = ? AND product_id = ?').bind(tenantId, prodId),
          ...units.map((u: any) =>
            c.env.DB.prepare(
              `INSERT INTO product_units (id, organization_id, product_id, unit_name, multiplier_to_base, is_base_unit, allow_loose_sale, can_buy, can_sell, price_paise, mrp_paise, created_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
            ).bind(
              `punit_${nowMs}_${Math.random().toString(36).substring(2, 6)}`,
              tenantId,
              prodId,
              (u.unitName || 'piece').toLowerCase().trim(),
              Number(u.multiplierToBase || 1),
              Number(u.multiplierToBase) === 1 ? 1 : 0,
              u.allowLooseSale !== false ? 1 : 0,
              u.canBuy !== false ? 1 : 0,
              u.canSell !== false ? 1 : 0,
              Number(u.wholesalePricePaise || 0),
              Number(u.mrpPaise || 0),
              nowMs
            )
          ),
          c.env.DB.prepare(
            `INSERT INTO server_outbox_audit (id, organization_id, user_id, idempotency_key, mutation_type, payload_hash, payload_json, provisional_business_id, server_business_id, client_sequence_order, server_sequence_order, processed_at_epoch_ms)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
          ).bind(
            `audit_${nowMs}_${currentSeq}`,
            tenantId,
            user.sub,
            idempotencyKey,
            mutationType,
            payloadHash,
            payloadString,
            provisionalBusinessId || null,
            prodId,
            sequenceOrder || 0,
            currentSeq,
            nowMs
          )
        ];

        await c.env.DB.batch(unitStmts);

        results.push({
          mutationId,
          status: 'COMMITTED',
          provisionalBusinessId,
          serverBusinessId: prodId,
          serverSequence: currentSeq
        });

      } else if (mutationType === 'STOCK_INWARD') {
        if (userRole !== 'WAREHOUSE' && userRole !== 'OWNER' && userRole !== 'ADMIN') {
          return c.json({
            success: false,
            error: 'FORBIDDEN_ROLE_ACTION',
            message: `Role '${userRole}' is not authorized to inward stock`
          }, 403);
        }

        const prodId = payload?.productId;
        const pieces = Number(
          payload?.piecesReceived ||
          payload?.looseQuantity ||
          (payload?.cartonsReceived
            ? (Number(payload.cartonsReceived) * Number(payload.piecesPerCarton || 20) + Number(payload.loosePiecesReceived || 0))
            : (payload?.quantity || 0))
        );
        const nowMs = Date.now();
        const inwardId = `inw_${nowMs}_${Math.random().toString(36).substring(2, 6)}`;
        currentSeq++;

        const prod = await c.env.DB.prepare(
          'SELECT stock_quantity FROM products WHERE id = ? AND company_id = ?'
        ).bind(prodId, tenantId).first<{ stock_quantity: number }>();

        const stockBefore = prod?.stock_quantity ?? 0;
        const stockAfter = stockBefore + pieces;

        await c.env.DB.batch([
          c.env.DB.prepare(
            'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ? AND company_id = ?'
          ).bind(pieces, prodId, tenantId),
          c.env.DB.prepare(
            `INSERT INTO stock_movements (id, company_id, product_id, batch_id, movement_type, quantity, stock_before, stock_after, reason, notes, created_by, created_at)
             VALUES (?, ?, ?, ?, 'INWARD_GRN', ?, ?, ?, 'STOCK_INWARD', ?, ?, ?)`
          ).bind(
            `mov_${nowMs}_${Math.random().toString(36).substring(2, 6)}`,
            tenantId,
            prodId,
            payload?.batchNumber || null,
            pieces,
            stockBefore,
            stockAfter,
            payload?.notes || 'Outbox Inward',
            user.sub,
            Math.floor(nowMs / 1000)
          ),
          c.env.DB.prepare(
            `INSERT INTO server_outbox_audit (id, organization_id, user_id, idempotency_key, mutation_type, payload_hash, payload_json, provisional_business_id, server_business_id, client_sequence_order, server_sequence_order, processed_at_epoch_ms)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
          ).bind(
            `audit_${nowMs}_${currentSeq}`,
            tenantId,
            user.sub,
            idempotencyKey,
            mutationType,
            payloadHash,
            payloadString,
            provisionalBusinessId || null,
            inwardId,
            sequenceOrder || 0,
            currentSeq,
            nowMs
          )
        ]);

        results.push({
          mutationId,
          status: 'COMMITTED',
          provisionalBusinessId,
          serverBusinessId: inwardId,
          serverSequence: currentSeq
        });

      } else if (mutationType === 'STOCK_ADJUSTMENT') {
        if (userRole !== 'OWNER' && userRole !== 'ADMIN') {
          return c.json({
            success: false,
            error: 'FORBIDDEN_ROLE_ACTION',
            message: 'Only Owner or Admin can perform stock adjustments or reversals'
          }, 403);
        }

        const prodId = payload?.productId;
        const delta = Number(
          payload?.quantityDelta ||
          (payload?.cartonDelta
            ? -(Number(payload.cartonDelta) * Number(payload.boxQty || 20))
            : (payload?.delta || 0))
        );
        const reason = payload?.reason || 'STOCK_ADJUSTMENT';
        const nowMs = Date.now();
        const adjId = `adj_${nowMs}_${Math.random().toString(36).substring(2, 6)}`;
        currentSeq++;

        const prod = await c.env.DB.prepare(
          'SELECT stock_quantity, reserved_quantity FROM products WHERE id = ? AND company_id = ?'
        ).bind(prodId, tenantId).first<{ stock_quantity: number; reserved_quantity: number }>();

        const stockBefore = prod?.stock_quantity ?? 0;
        const stockAfter = stockBefore + delta;
        if (stockAfter < (prod?.reserved_quantity ?? 0)) {
          return c.json({
            success: false,
            error: 'INSUFFICIENT_STOCK',
            message: 'Cannot adjust stock below current unpicked reservations'
          }, 400);
        }

        await c.env.DB.batch([
          c.env.DB.prepare(
            'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ? AND company_id = ?'
          ).bind(delta, prodId, tenantId),
          c.env.DB.prepare(
            `INSERT INTO stock_movements (id, company_id, product_id, movement_type, quantity, stock_before, stock_after, reason, notes, created_by, created_at)
             VALUES (?, ?, ?, 'ADJUSTMENT', ?, ?, ?, ?, ?, ?, ?)`
          ).bind(
            `mov_${nowMs}_${Math.random().toString(36).substring(2, 6)}`,
            tenantId,
            prodId,
            delta,
            stockBefore,
            stockAfter,
            reason,
            payload?.notes || reason,
            user.sub,
            Math.floor(nowMs / 1000)
          ),
          c.env.DB.prepare(
            `INSERT INTO server_outbox_audit (id, organization_id, user_id, idempotency_key, mutation_type, payload_hash, payload_json, provisional_business_id, server_business_id, client_sequence_order, server_sequence_order, processed_at_epoch_ms)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
          ).bind(
            `audit_${nowMs}_${currentSeq}`,
            tenantId,
            user.sub,
            idempotencyKey,
            mutationType,
            payloadHash,
            payloadString,
            provisionalBusinessId || null,
            adjId,
            sequenceOrder || 0,
            currentSeq,
            nowMs
          )
        ]);

        results.push({
          mutationId,
          status: 'COMMITTED',
          provisionalBusinessId,
          serverBusinessId: adjId,
          serverSequence: currentSeq
        });

      } else if (mutationType === 'APPROVE_RETAILER') {
        if (userRole !== 'OWNER' && userRole !== 'ADMIN') {
          return c.json({
            success: false,
            error: 'FORBIDDEN_ROLE_ACTION',
            message: 'Only Owner or Admin can approve retailers'
          }, 403);
        }

        const retailerId = payload?.retailerId;
        const creditLimitPaise = Number(payload?.creditLimitPaise || 0);
        const classification = payload?.classification || 'CLASS_C';
        const nowMs = Date.now();
        currentSeq++;

        await c.env.DB.batch([
          c.env.DB.prepare(
            'UPDATE retailers SET is_active = 1, credit_limit_paise = ?, classification = ? WHERE id = ? AND company_id = ?'
          ).bind(creditLimitPaise, classification, retailerId, tenantId),
          c.env.DB.prepare(
            `INSERT INTO server_outbox_audit (id, organization_id, user_id, idempotency_key, mutation_type, payload_hash, payload_json, provisional_business_id, server_business_id, client_sequence_order, server_sequence_order, processed_at_epoch_ms)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
          ).bind(
            `audit_${nowMs}_${currentSeq}`,
            tenantId,
            user.sub,
            idempotencyKey,
            mutationType,
            payloadHash,
            payloadString,
            provisionalBusinessId || null,
            retailerId,
            sequenceOrder || 0,
            currentSeq,
            nowMs
          )
        ]);

        results.push({
          mutationId,
          status: 'COMMITTED',
          provisionalBusinessId,
          serverBusinessId: retailerId,
          serverSequence: currentSeq
        });

      } else {
        // Mutation type without a real domain handler: MUST NEVER BE ACCEPTED SILENTLY
        results.push({
          mutationId,
          status: 'REJECTED',
          provisionalBusinessId,
          errorCode: 'UNSUPPORTED_MUTATION_TYPE',
          errorMessage: `Mutation type '${mutationType}' is not supported for server processing.`
        });
      }
    }

    return c.json({
      success: true,
      clientBatchId: clientBatchId || 'batch_ack',
      processedCount: results.length,
      serverProcessedEpochMs: Date.now(),
      results
    }, 200);
  });

  // --------------------------------------------------------------------------
  // POST /sync/pull — Delta Pull of Updated Catalog, Orders & Class Settings
  // --------------------------------------------------------------------------
  router.post('/sync/pull', async (c) => {
    const user = c.get('user');
    const tenantId = user.company_id;

    let body: any = {};
    try {
      body = await c.req.json();
    } catch {
      // Body is optional; default to blank
    }

    const { organizationId, lastServerSequence, limit } = body || {};

    if (organizationId && organizationId !== tenantId) {
      return c.json({
        success: false,
        error: 'TENANT_MISMATCH',
        message: `Cross-tenant violation: requested organizationId '${organizationId}' does not match authenticated tenant '${tenantId}'`
      }, 403);
    }

    const maxAudit = await c.env.DB.prepare(
      'SELECT MAX(server_sequence_order) as maxSeq FROM server_outbox_audit WHERE organization_id = ?'
    ).bind(tenantId).first<{ maxSeq: number | null }>();

    const latestServerSequence = maxAudit?.maxSeq ?? 0;
    const fetchLimit = Math.min(Number(limit) || 100, 250);

    // Delta fetch
    const products = await c.env.DB.prepare(
      'SELECT id, name, category, price_paise, stock_quantity, reserved_quantity, unit FROM products WHERE company_id = ? LIMIT ?'
    ).bind(tenantId, fetchLimit).all();

    const classSettings = await c.env.DB.prepare(
      'SELECT class_name as className, default_credit_limit_paise as defaultCreditLimitPaise, credit_days as creditDays, visit_frequency_days as visitFrequencyDays, updated_at_epoch_ms as updatedAt FROM retailer_class_settings WHERE organization_id = ?'
    ).bind(tenantId).all();

    const orderStatusUpdates = await c.env.DB.prepare(
      'SELECT id as serverOrderId, status as newStage, total_amount_paise FROM orders WHERE company_id = ? ORDER BY updated_at DESC LIMIT ?'
    ).bind(tenantId, fetchLimit).all();

    const retailers = await c.env.DB.prepare(
      'SELECT id, name, contact_number as phone, address, credit_limit_paise as creditLimitPaise, outstanding_amount_paise as outstandingPaise, classification, is_active as isActive, latitude, longitude FROM retailers WHERE company_id = ? LIMIT ?'
    ).bind(tenantId, fetchLimit).all();

    const productUnits = await c.env.DB.prepare(
      'SELECT product_id as productId, unit_name as unitName, multiplier_to_base as multiplierToBase, price_paise as pricePaise, can_sell as canSell, can_buy as canBuy FROM product_units WHERE organization_id = ?'
    ).bind(tenantId).all();

    return c.json({
      success: true,
      latestServerSequence,
      hasMore: false,
      delta: {
        products: products.results || [],
        productUnits: productUnits.results || [],
        retailers: retailers.results || [],
        classSettings: classSettings.results || [],
        orderStatusUpdates: orderStatusUpdates.results || []
      }
    }, 200);
  });

  return router;
}
