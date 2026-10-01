-- Forward-only corrections. No historical records are deleted or revalued.
CREATE TABLE auth_rate_limits (
 scope TEXT NOT NULL, subject_hash TEXT NOT NULL, window_start INTEGER NOT NULL,
 attempts INTEGER NOT NULL, PRIMARY KEY(scope,subject_hash,window_start)
);
CREATE TRIGGER refresh_rotation_claim BEFORE INSERT ON revoked_refresh_tokens BEGIN
 SELECT CASE WHEN NOT EXISTS (SELECT 1 FROM sessions WHERE id=NEW.session_id AND user_id=NEW.user_id
 AND refresh_token_hash=NEW.token_hash AND is_revoked=0 AND expires_at>NEW.revoked_at)
 THEN RAISE(ABORT,'Refresh token already rotated or session unavailable') END;
END;
CREATE TRIGGER credit_reservation_limit BEFORE INSERT ON credit_reservations BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM orders o JOIN retailers r ON r.id=o.retailer_id
 WHERE o.id=NEW.order_id AND o.company_id=NEW.company_id AND r.company_id=NEW.company_id
 AND NEW.retailer_id=r.id AND NEW.amount_paise=o.total_amount_paise
 AND r.outstanding_amount_paise+NEW.amount_paise+COALESCE((SELECT SUM(amount_paise) FROM credit_reservations
 WHERE retailer_id=NEW.retailer_id AND company_id=NEW.company_id AND order_id!=NEW.order_id),0)
 <=r.credit_limit_paise+CASE WHEN o.status='SUBMITTED' THEN o.credit_override_paise ELSE 0 END)
 THEN RAISE(ABORT,'Credit exposure exceeds limit') END;
END;
CREATE TRIGGER nonnegative_stock_reservation BEFORE UPDATE OF reserved_quantity ON products
 WHEN NEW.reserved_quantity<0 BEGIN SELECT RAISE(ABORT,'Reserved stock cannot be negative'); END;
CREATE TRIGGER cash_reversal_custody BEFORE UPDATE OF status ON collections
 WHEN NEW.status='REVERSED' AND OLD.payment_method='CASH' BEGIN
 SELECT CASE WHEN EXISTS(SELECT 1 FROM cash_handovers WHERE company_id=OLD.company_id
 AND user_id=OLD.collected_by AND status='PENDING') OR OLD.amount_paise>
 COALESCE((SELECT SUM(CASE WHEN entry_type='CASH_REVERSAL' THEN -amount_paise ELSE amount_paise END)
 FROM payment_ledger WHERE company_id=OLD.company_id AND collected_by=OLD.collected_by
 AND entry_type IN ('CASH_PAYMENT','CASH_REVERSAL')),0)-
 COALESCE((SELECT SUM(received_amount_paise) FROM cash_handovers WHERE company_id=OLD.company_id
 AND user_id=OLD.collected_by AND status='ACCEPTED'),0)
 THEN RAISE(ABORT,'Cash reversal exceeds available custody') END;
END;
CREATE TRIGGER shift_transition_guard BEFORE UPDATE OF status ON shifts BEGIN
 SELECT CASE WHEN OLD.status='OFF_SHIFT' OR NOT (
 (OLD.status='ON_SHIFT' AND NEW.status IN ('ON_BREAK','OFF_SHIFT')) OR
 (OLD.status='ON_BREAK' AND NEW.status IN ('ON_SHIFT','OFF_SHIFT')))
 THEN RAISE(ABORT,'Shift transition already applied or invalid') END;
END;
CREATE TRIGGER shift_point_ownership BEFORE INSERT ON shift_locations BEGIN
 SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM shifts WHERE id=NEW.shift_id AND company_id=NEW.company_id
 AND user_id=NEW.user_id AND NEW.timestamp>=start_time AND (end_time IS NULL OR NEW.timestamp<=end_time))
 OR EXISTS(SELECT 1 FROM shift_breaks WHERE shift_id=NEW.shift_id AND NEW.timestamp>=start_time
 AND (end_time IS NULL OR NEW.timestamp<end_time)) THEN RAISE(ABORT,'Location outside owned working shift') END;
END;
