# Dependable daily cycle — implementation checklist

Scope: visit → order → approval → warehouse → delivery → collection → handover → owner closing.
Existing business data must be preserved. No deployment, publishing, database reset, or Git push.

- [x] Inspect instructions, clean Git status, current implementation and acceptance documents.
- [x] Confirm physical Vivo device is connected (not acceptance evidence).
- [ ] Add non-destructive financial migrations: settlement/allocation/reversal, return reservations, credit exposure and cash custody guards.
- [ ] Enforce endpoint permissions and truthful server-owned delivery proof.
- [ ] Add backend regression tests using isolated local test storage.
- [ ] Make visits, stock checks, shift events, locations and collections durable and account-bound.
- [ ] Complete employee/owner handover, discrepancy history and daily closing UI.
- [ ] Wire payment verification/reversal and return lifecycle UI.
- [ ] Finish bilingual daily workflow, truthful metrics, recoverable sync failures and draft preservation.
- [ ] Run backend typecheck and regression/integration tests.
- [ ] Run Android unit tests, lint and APK build sequentially.
- [ ] Exercise actual phone screens, offline restart/reconnection, English/Hindi and duplicate actions.
- [ ] Measure representative shift battery/data usage (short spot checks do not satisfy this).
- [ ] Update README and acceptance matrix with actual evidence and remaining dependencies.

External dependency: real recipient OTP delivery requires an acknowledged SMS provider integration and credentials. Until configured, report unavailable; development simulation must be explicit and cannot prove production delivery.
