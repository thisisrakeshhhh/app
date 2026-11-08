<USER_REQUEST>
# ROUTEFLOW — SALES PACK 1: RATE CARD + STATEMENT SHARE, FOLLOW-UPS, SHELF CHECK, LOST AND MISSED SALES

This continues `docs/ROUTEFLOW_SALES_ROLE_SPEC.md`. Same rules as before: sales code lives in `lib/features/sales/`, other roles must not change, nothing is pushed, no remotes, no credentials, no new packages without asking (one exception below), no fake data, tests first, full gates after every slice, one commit per slice, update `docs/ROUTEFLOW_PROGRESS.md`, say UNVERIFIED for anything you did not measure.

## 0. PREREQUISITES (check first, and stop if they fail)

1. S1b (fonts + conversion of sales screens to `AppStrings`) and S2 (sales shell, `salesV2Enabled`, `test/role_isolation_test.dart`) are committed and the full suite is green. If not, stop and tell me.
2. Paste `git status`, `git log --oneline -5`, and the raw last lines of `flutter analyze` and `flutter test`.
3. Search `lib/` outside the demo seed for hardcoded product or brand names (for example "Kurkure", "Bikaneri", "Real Bites"). Paste the hits. Nothing in this pack may hardcode a product, brand or distributor name. The distributor name in messages comes from the signed-in organization profile; if it is missing, omit it.

## 1. HONEST SCOPE (read this, it changes what you build)

- Everything in this pack is **phone-local**. The server does not have handlers for these record types, so do NOT enqueue outbox mutations for them (the server would reject them and clutter "Needs attention"). Mark each record `sync_state = 'LOCAL_ONLY'` and show a plain localized "Saved on this phone" label wherever it is listed.
- Because the data is local, an owner's phone will **not** see a rep's shelf checks, lost-sale reasons or missed sales yet. Do not build owner screens in this pack. Owner reporting is a separate later slice (P4, section 7) that needs server work and my approval.
- Reminders are in-app only. Without a notification package, a reminder is visible only when the app is open. Say so in the report and in a short help line on the reminders screen. Do not add `flutter_local_notifications` or any notification package without asking me.
- No "verified" wording anywhere. Statements and rate cards are "from this phone", not official invoices.

## 2. ISOLATION AND LANGUAGES (unchanged rules)

- New code in `lib/features/sales/` with `sales_` prefixes; additive migrations only (new tables); shared-file edits listed with diffs; role-isolation test extended so owner, admin, warehouse and delivery never show any new widget.
- Every user-facing string has en, hinglish, hi and gu values in `AppStrings` (test fails on any gap) and is added to `docs/ROUTEFLOW_TRANSLATION_REVIEW.md` with `reviewed: false`. No hardcoded literals in new screens. Starting translations:

| Meaning | Hinglish | Hindi | Gujarati |
|---|---|---|---|
| Shelf check | Dukaan ka maal dekho | दुकान का माल देखें | દુકાનનો માલ તપાસો |
| Not there | Nahi hai | नहीं है | નથી |
| Low | Kam | कम | ઓછો |
| OK | Theek | ठीक | બરાબર |
| Plenty | Zyada | ज़्यादा | વધારે |
| Stock available at shop | Stock hai | स्टॉक है | સ્ટોક છે |
| Rate too high | Rate zyada | रेट ज़्यादा | ભાવ વધારે |
| Bought from other | Dusre se liya | दूसरे से लिया | બીજા પાસેથી લીધું |
| No need | Zaroorat nahi | ज़रूरत नहीं | જરૂર નથી |
| Skip | Chhodo | छोड़ें | છોડો |
| Today / Tomorrow / Day after | Aaj / Kal / Parso | आज / कल / परसों | આજે / કાલે / પરમદિવસે |
| Follow-up | Yaad dilana | याद दिलाना | યાદ અપાવવું |
| Missed sale | Maal nahi tha | माल नहीं था | માલ નહોતો |
| Rate card | Rate list | रेट लिस्ट | ભાવ યાદી |
| Statement | Hisaab | हिसाब | હિસાબ |

Product names in messages: use the English product name; use the Hindi name field for Hindi and Hinglish only if it exists; Gujarati falls back to the English name (there is no Gujarati name field yet).

## 3. SLICE P1: WHATSAPP RATE LIST AND HISAAB STATEMENT (no new tables)

**Package:** `share_plus` was already approved for the WhatsApp bill (S5). If it is not in `pubspec.yaml` yet, add it once (version pinned, published at least two weeks ago; say the version). Use the system share sheet only. Do not add `url_launcher` and do not open `whatsapp://` links. Never claim a message was delivered or read. First check what the existing WhatsApp button does today (it showed a SnackBar placeholder) and replace that behaviour.

### P1a Rate list ("Rate list")
- **Where:** Shops tab, a button in the header row ("Share rate list"); also a smaller link on the shop card ("Rates for this shop").
- **Sheet before sharing:** choose scope: "All shops (default prices)" or "This shop's prices"; choose categories (chips, all selected by default); a preview of the text; button "Share".
- **Content, only real data:** distributor name (from profile, omit if missing); date and time generated; a heading line; then one line per product: name, and for each unit that is sellable the current price (use the same price resolution the order screen uses for that shop, or the default price for "all shops"); optionally MRP if present. Only active products that currently have available stock greater than 0; out-of-stock items are left out unless the rep ticks "Include out of stock" (then shown as "Stock nahi" in the user's language). No purchase cost, no margin, no credit limit, never other shops' data. Schemes are included only if scheme data exists (it does not yet; omit the section).
- **Footer:** "Rates change ho sakte hain" in the selected language plus the time stamp.
- **Length:** cap at 40 product lines per message; if more, ask the rep to pick categories, never silently cut.
- **Not available state:** if no products or no prices exist, show "Rates available nahi" with no share button.

### P1b Hisaab statement ("Statement")
- **Where:** shop card, button "Send hisaab".
- **Content, only real data on this phone:** shop name; date generated; the last 3 orders (date, order reference, item count, total in rupees, wording "Saved on this phone" if not synced); the current outstanding (from the existing ledger value, label "Baaki"). A "payments received" section appears only if collection records exist (they do not until S4); otherwise omit it with no placeholder. **Never include the credit limit or the shop's class** (these are internal). Footer: "Yeh phone ka hisaab hai. Final hisaab distributor ke records se milega." in the user's language. Do not use the words "verified" or "official".
- **Edge cases:** shop with no orders shows only the outstanding and a plain note; shop with no outstanding says so.

**Tests (P1):** rate list contains only active, in-stock products with the correct unit prices from a fixed fixture; shop-specific price differs from the default price when an override exists; out-of-stock included only on opt-in; 40-line cap prompts for categories; no cost or margin strings appear; statement shows last 3 orders and outstanding from a fixture and never includes credit limit or class; templates render correctly in all four languages with Latin digits and Indian grouping; no "verified" text; share is invoked via the share interface (use a fake) and no delivery claim appears; role isolation.

## 4. SLICE P2: FOLLOW-UPS (reminders)

One reminder system only. S4 (collections) will create "payment promise" and "cheque date" items; they must reuse this table, never a second one. Build a general table now.

**Table `follow_ups` (additive migration):** `id` (UUID), `organization_id`, `user_id`, `retailer_id`, `type` (`COLLECT_PAYMENT`, `CHEQUE`, `VISIT`, `FIRST_ORDER`, `OTHER`), `title` (short text, may be empty when a preset is used), `note`, `amount_paise` (nullable, integer), `due_at` (date and optional time), `status` (`OPEN`, `DONE`, `SNOOZED`, `CANCELLED`), `created_at`, `done_at`, `sync_state` (`LOCAL_ONLY`). Indexes on `(user_id, status, due_at)` and `(retailer_id)`.

**Where:**
- Shop card: button "+ Yaad dilana" (add follow-up).
- Today tab: a chip "Follow-ups (N)" showing items due today or overdue; tapping lists them sorted overdue first. On the route list, a small bell icon appears on shops that have an open follow-up due today or earlier.
- Shop card: a section listing that shop's open follow-ups.

**Add flow (fast for low-reading users):** pick a type icon; pick a date with big chips "Aaj / Kal / Parso" or a date picker; optional time; optional amount (large keypad, rupees, converted to paise) shown for payment and cheque types; optional short note typed or left empty. One "Save" button.
**Actions on an item:** "Ho gaya" (done), "Kal tak taalo" (snooze to tomorrow), "Hatao" (cancel with a confirm). Cancelled and done items stay in history, never deleted.
**Rules:** records are scoped by user and organization and ignored after logout or tenant switch; double-tap save creates one record (idempotency token); an overdue item is shown in red with the word "Late", not color alone; the amount, if shown, is labelled as a reminder amount ("yaad ke liye"), never as a ledger balance.
**Help line (localized):** "Yaad dilana tab dikhega jab app khula ho." (reminders show when the app is open).

**Tests (P2):** add each type; due-today and overdue appear in the Today chip and the bell icon; snooze moves to tomorrow; done and cancel keep the row; double-tap creates one; persistence across restart; isolation between two users and two organizations; paise stored as integers; all four languages; role isolation.

## 5. SLICE P3: SHELF CHECK, LOST-SALE REASONS, MISSED SALES (three new tables, local only)

### P3a Shelf check
**Table `shelf_checks`:** `id`, `organization_id`, `user_id`, `retailer_id`, `product_id`, `level` (`OUT`, `LOW`, `OK`, `PLENTY`), `qty_base` (nullable integer), `checked_at`, `sync_state`.
- **Where:** shop card, button "Dukaan ka maal dekho" shown after check-in and before "Take order".
- **Which products:** data-driven, never hardcoded. Take that shop's top 5 products by frequency in its last 8 orders. If the shop has fewer than 3 orders, use the 5 most-ordered active products across the rep's local orders. If there are no orders at all, show "Order history chahiye" and no list.
- **Entry:** for each product one row with four big chips (Nahi hai / Kam / Theek / Zyada) and an optional quantity stepper in the product's smallest sensible unit. One "Save" at the bottom; "Chhodo" skips.
- **Effect on the suggested order (only if the suggestion engine from S3 exists; otherwise implement as a pure function with tests and wire it when S3 lands):** a shelf check less than 3 days old changes the suggestion: `PLENTY` reduces the suggested quantity to zero with the reason line "Dukaan me zyada maal hai"; `OUT` or `LOW` keeps or raises it to the shop's typical quantity; `OK` leaves it unchanged. Always show the reason. Never invent quantities.

### P3b Lost-sale reasons
**Table `lost_sale_reasons`:** `id`, `organization_id`, `user_id`, `retailer_id`, `product_id`, `reason` (`SHOP_HAS_STOCK`, `RATE_HIGH`, `COMPETITOR`, `NO_NEED`), `order_ref` (nullable), `created_at`, `sync_state`.
- **When to ask (important, to avoid annoying the rep):** only at the review screen, once, for products that are in the suggested order or that the shop bought in at least 2 of its last 8 orders but that are **not in this cart**. Maximum 5 items. Never ask during cart edits, never when an item is merely reduced, never for a product the shop never buys.
- **UI:** one card "In items ko kyun nahi liya?" listing the items, each with four chips (Stock hai / Rate zyada / Dusre se liya / Zaroorat nahi) and a "Chhodo" button; a single "Chhodo sab" skips everything. It never blocks submitting the order.
- **No-order visits:** the existing visit outcomes stay as they are; do not duplicate them.

### P3c Missed sale (stock-out)
**Table `missed_sales`:** `id`, `organization_id`, `user_id`, `retailer_id`, `product_id`, `unit_name`, `unit_qty` (integer), `requested_base_qty` (integer), `available_base_at_time` (integer), `estimated_value_paise` (integer, computed from that shop's price for that unit times the quantity at that moment), `created_at`, `sync_state`.
- **When:** the order screen already blocks quantities above available stock. Add an explicit button on that block message: "Maal nahi tha, likh lo". Only that button creates a record (never a stray tap). It opens a small confirm showing the product and the quantity the shop asked for (stepper) and a "Save" button.
- **Label:** the value is shown as "andaaza" (estimated) and never as revenue.
- **Idempotency:** double-tap creates one record.

**Tests (P3):** top-5 selection from a fixed order fixture, fallback, and empty state; shelf levels persist and expire for suggestions after 3 days; `PLENTY` zeroes a suggestion with a visible reason; lost-sale prompt appears only for the right products and at most 5, never blocks submission, and "skip all" writes nothing; missed sale is created only via the explicit button with the correct integer paise estimate; double-tap guards; all records are scoped by user and organization; no outbox rows are created for any of the three tables; languages; role isolation.

## 6. DATABASE AND MIGRATION RULES

One additive migration for `follow_ups`, `shelf_checks`, `lost_sale_reasons`, `missed_sales` (create per slice if you prefer separate migrations). No changes to existing tables. A migration test opens a real previous-version database with rows and confirms nothing is lost. Money is integer paise, quantities are integer base units.

## 7. NOT IN THIS PACK (ask me first)

- **P4: server ingestion and owner reports.** Backend handlers and D1 tables for the four record types, pull into the owner device, an owner card "Lost sales this week" (missed sales in estimated rupees, lost-sale reasons by count, shelf-check coverage). Needs my approval because it touches the backend.
- **Credit risk and overdue aging view for the owner.** The data does not exist yet: the app has no invoice due dates or payment history. It becomes possible after collections (S4) and due dates are stored. Do not build it now and do not approximate it.
- **Practice sandbox for freshers.** Later. It must use a separate in-memory database that can never write to the real database or the outbox. Do not start it.
- **Margin report.** Needs purchase cost on every receipt.

## 8. REPORTS AND DONE

After each slice: files inspected, files changed (shared files listed separately with diffs), migrations, tests added (names), raw last lines of `flutter analyze` and the full `flutter test`, `git log --oneline -5`, `git status`, and what you could not verify. If a gate fails twice, stop and report. Stop after P3 and wait for my "approved" before starting P4.

Begin with section 0.
</USER_REQUEST>
<ADDITIONAL_METADATA>
The current local time is: 2026-11-08T01:16:49+05:30.
</ADDITIONAL_METADATA>