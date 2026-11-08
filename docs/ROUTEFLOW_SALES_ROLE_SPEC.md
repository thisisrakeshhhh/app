<USER_REQUEST>
# ROUTEFLOW — SALES ROLE: FIXES, 4 LANGUAGES, AND NEW FEATURES (ISOLATED FROM OTHER ROLES)

Read all of this before touching anything. Work in the order given. This project has several roles (owner, admin, sales, warehouse, delivery). **Nothing in this prompt may change how the other roles look or behave.**

---

## 0. HARD RULES (stricter than before, because of what happened last run)

1. **NEVER run `git push`, `git remote add/set-url/remove`, `git credential`, or `gh`.** Never read the credential manager, `~/.ssh`, environment variables holding tokens, or any token. Never call the GitHub API. Last run you changed the remote, read stored credentials, called the API, and pushed. I did not allow any of that. Do not repeat it. If you think a push is needed, ask me and wait.
2. Do not change git remotes. Run `git remote -v` and paste it. Run `git reflog | head -40` and tell me what the `origin` URL was before you changed it. Then stop touching remotes.
3. No fake data anywhere: no invented addresses, distances, times, stock, targets or earnings. If data is missing, hide the element or show a clear "not available" state with an action to add it.
4. No new packages without asking me first. Assets (fonts) are allowed under section 5.
5. Money is integer paise. Quantities are integer base units. Errors are plain language in the user's chosen language.
6. All earlier rules still apply: tests first, gates after each slice (`flutter analyze`, full `flutter test`, backend `npm test` only if you touched backend), one commit per slice, update `docs/ROUTEFLOW_PROGRESS.md`, mark anything unproven UNVERIFIED, never weaken a test.
7. Do not touch the backend in this prompt. Anything that would need the server stays local-only and honestly labelled "Saved on this phone".

---

## 1. STEP 0: FIX THE PROBLEMS IN COMMIT babdad1 (do this first, one commit)

I read the public diff of that commit. Fix these, with tests:

**1.1 Fabricated address numbers.** `RetailerShop.scoNo` and `gaaliNo` invent values from `id.hashCode` (`'SCO #$hashNum-A'`, `'Gali No. $hashGali'`) when the address has none. A rep can be sent to an address that does not exist. Delete the invented fallbacks. Show a unit/street line only if the real address text contains it. Otherwise show the real address as stored, or "Address not added" with an "Add address" button. Add a test: a shop with no SCO/Gali text shows no SCO/Gali text.

**1.2 Class names.** `classDisplayName` switches on `'CLASS_A'`, `'CLASS_B'` and so on, but the database design stores `A`, `B`, `C`, `D`, `NEW`. Show what is actually stored in the Drift `retailers.class_type` column and the values the app writes. If they differ, every shop shows "Class NEW" today. Fix it. Remove marketing text like "5★ High Volume". The chip is the letter plus a localized word ("A", "B"...), color plus letter, never color alone.

**1.3 No tests were added for the whole commit.** Tests stayed at 249 and the commit touches only lib files. Add tests for: route map view (renders pins from real shop coordinates, handles zero shops, shops without coordinates), combo order sheet (1 box + 1 strip + 5 pcs = correct pieces and price), timeframe KPIs (today/week/month/year/since joining on a fixed sample of orders), toggling a shop in the route, role gating (see section 2). Paste the new test names and real totals.

**1.4 Shared header changed for every role.** The GST summary button and other items in `role_shell.dart` were changed for all roles "per your request". Restore the GST summary for owner, admin and any accounting roles. Hide it only for the sales role, through a role check. Show the diff. Add a test: owner sees the GST button, sales does not.

**1.5 Route map honesty.** The map is a custom-drawn canvas. State exactly how pin positions are computed. If they come from real latitude/longitude scaled into the canvas, say so and label it "Route sketch (not to scale)". If positions are arbitrary, fix them or relabel. The "pulsing GPS icon" must reflect a real GPS reading with an "as of <time>" or be removed. No invented distances or travel times. Opening Google Maps for navigation is allowed through the system map app link only if a launcher mechanism already exists; otherwise ask me before adding one.

**1.6 Reps editing the route.** The new "Route" sheet lets a salesperson toggle any shop in or out of the route. Routes are owner/manager-controlled with manual stop order. Make it permission-based: by default a rep can only add an "extra visit today" (marked as extra, never changing the owner's route order) and cannot remove assigned shops. Show where the toggle is stored: memory or Drift? If memory only, it is lost on restart: persist it or label it. Test it.

**1.7 Metrics definitions.** Write each Today KPI's exact formula in `docs/ROUTEFLOW_METRICS.md`: booked orders, booked value, beat coverage, average order value (booked value divided by order count), "strike rate" (productive visits divided by visits). Label them "from orders on this phone" until pull sync covers all orders. Do not call booked value revenue.

**1.8 Full rewrite of `sales_dashboard.dart`.** Paste `git diff --stat babdad1~1..babdad1`. Confirm "Continue route", "Order again", the stepper, search and the cart still work with existing tests.

**1.9 What was pushed.** The repository you pushed to, `thisisrakeshhhh/app`, is **public** (I opened a commit page without logging in). Without pushing anything else, run `git ls-files | grep -iE "\.env|secret|token|\.jks|\.keystore|google-services|\.sqlite|\.db$|\.pem|\.p12"` and `git log --all --oneline -S"BEGIN PRIVATE KEY"` and a search of the tracked files for strings like `Bearer `, `api_key`, `secret`, `password`. Paste the results. If anything sensitive shows up, tell me immediately and stop. Do not try to delete remote history yourself.

Then continue to section 2. Commit Step 0 as `fix: sales role corrections after babdad1`.

---

## 2. ISOLATION: HOW TO BUILD WITHOUT AFFECTING OTHER ROLES

1. **All new sales code goes in a new folder:** `flutter_distributor/lib/features/sales/` with subfolders `screens/`, `widgets/`, `services/`, `models/`. Name new files with a `sales_` prefix.
2. **Do not grow `ApiService`.** Create `lib/features/sales/services/sales_feature_service.dart` (a `ChangeNotifier`) that takes `ApiService` and `LocalRepository` as constructor dependencies. Only add tiny additive getters or methods to `ApiService` when truly needed, and list each one.
3. **Shared files you may touch, additively only:** `l10n/app_strings.dart` (new keys), `role_shell.dart` (only the sales branch and the language switch icon), `models.dart` (additive getters), `app_database.dart` (additive tables/columns with a migration). Every edit to a shared file is listed in the slice report with a one-line justification and its diff.
4. **Mount sales features only for the sales role**, inside the sales branch of `role_shell.dart`, via a new `SalesShell` widget. Keep the old sales dashboard files in place until the new shell replaces them in the same commit and tests are green.
5. **Feature flag:** `salesV2Enabled` (default true for the sales role only, false for others). Store it in the existing local settings. Turning it off restores the previous sales screens.
6. **Role regression tests (new file `test/role_isolation_test.dart`):** for owner, admin, warehouse and delivery, pump the shell and assert their key widgets are present and none of the new sales widgets exist; assert existing role-routing behavior is unchanged; assert each role's logout works.
7. **Database:** new tables only, additive, migrations tested with a real previous-version database. Do not alter or drop columns used by other roles.
8. After each slice, run the **full** test suite, not only the new tests, and report the real pass count. If a pre-existing test fails, stop and fix the cause, never the test.

---

## 3. NAVIGATION FOR THE SALES ROLE (propose, then implement in Slice S2)

Four tabs, large icons plus words: **Today**, **Shops**, **Earn**, **More**.

| New tab | Contains | Moved from |
|---|---|---|
| Today | Home KPIs, "Continue route", route map, "Aaj ka kaam" list | Current Home / Route Map |
| Shops | Shop list and map toggle, search, filters (class, due, not visited), "+ Add Shop", the shop card | Current Retailers |
| Earn | My numbers, target and incentive progress (when configured), day close | New |
| More | Order history, visits history, sync status, language, help | Current History, Profile |

Rules: a new order is started from a shop (shop card → "Take order"); keep the bottom cart bar behaviour. Khata/hisab for a shop lives inside its shop card; add a "Due" filter in Shops. **Nothing existing is removed**; show me a mapping table of every old screen to its new place and a test that each old entry point is still reachable. Do this in its own commit after Slice S1 so it can be reverted alone.

---

## 4. LANGUAGES: ENGLISH, HINGLISH, HINDI, GUJARATI

### 4.1 Architecture
- `enum AppLanguage { en, hinglish, hi, gu }` (Hinglish = Hindi written in Roman letters, locale tag `hi-Latn`; Hindi = Devanagari; Gujarati = Gujarati script). Marwari is not a separate pack for now; Marwari-speaking users use Hindi or Hinglish.
- Extend the existing `AppStrings` (no new package). Every user-facing string has a key with four values. API: `AppStrings.of(context).t('key')` with named placeholders (for example `{count}`, `{amount}`). A missing translation falls back to English, never shows the key. Plurals handled per language where needed.
- A `LanguageController` (`ChangeNotifier`) switches the language instantly, without restart. It is saved per user and per device in existing local storage, and restored at startup.
- **Language picker:** shown once at first sales login as four big buttons showing their own names: **English**, **Hinglish**, **हिन्दी**, **ગુજરાતી**. Also on More → Language and as a small globe icon at the top-right of Today for a one-tap switch. Default is Hinglish for new sales users until they choose.
- **Fonts:** bundle Noto Sans Devanagari and Noto Sans Gujarati as asset fonts (OFL licence, only the needed weights, and tell me the APK size change). Use a taller line height (about 1.4) for Indic scripts. Verify nothing clips at 130% text scale on a 360 dp screen.
- **Numbers:** Latin digits, Indian grouping (₹1,42,800), currency symbol ₹. Dates like `4 Nov`. Do not switch to Gujarati digits.
- **Unit and trade words** must be localized, not left English. Use this glossary as the starting point and mark every Hindi and Gujarati string `reviewed: false` in a side file `docs/ROUTEFLOW_TRANSLATION_REVIEW.md`; a native speaker must approve before release:

| English | Hinglish | Hindi | Gujarati |
|---|---|---|---|
| Today | Aaj | आज | આજ |
| Shop | Dukaan | दुकान | દુકાન |
| Order | Order | ऑर्डर | ઓર્ડર |
| Box / case | Peti | पेटी | પેટી |
| Piece | Nag | नग | નંગ |
| Strip | Strip | स्ट्रिप | સ્ટ્રિપ |
| Stock | Maal | माल | માલ |
| Due / outstanding | Baaki | बाकी | બાકી |
| Credit / khata | Udhaar | उधार | ઉધાર |
| Account / hisab | Hisaab | हिसाब | હિસાબ |
| Collection | Vasooli | वसूली | ઉઘરાણી |
| Cash | Nakad | नकद | રોકડા |
| Cheque | Cheque | चेक | ચેક |
| Scheme | Scheme | स्कीम | સ્કીમ |
| Discount | Chhoot | छूट | છૂટ |
| Route | Route | रूट | રૂટ |
| Saved on this phone | Phone me save hua | फ़ोन में सेव हुआ | ફોનમાં સેવ થયું |

- Hinglish rules: Roman letters only, short everyday words, no mixed scripts in one sentence. Examples: "Aaj ka kaam", "Dukaan jodo", "Vasooli karo", "Order sahi hai?".
- Voice read-aloud (text-to-speech) and voice order need packages and device language voices. **Do not add them now.** Prepare the keys only, and ask me in a later slice (S6).

### 4.2 Language tests
- Every key has non-empty en, hinglish, hi and gu values (test fails on any gap).
- A scan of `lib/features/sales/` finds zero hardcoded user-facing `Text('...')` literals.
- Switching language updates visible text instantly in Today, Shops, shop card, cart and Earn (widget tests for each of the four).
- No clipped text at 130% scale for Hindi and Gujarati on a 360 dp width.
- Persistence across restart and per-user isolation (user A's choice does not change user B's).

---

## 5. THE FEATURES (build in this order; each slice has its own commit and tests)

For every feature: handle loading, empty, error and offline states; use only real data; use localized strings; use large touch targets (at least 48 dp); and keep sales-role gating. If the required data does not exist yet, build the data capture first, or hide the feature. Never show a placeholder number.

### Slice S1: Language foundation (section 4)
Implement the language system, picker, fonts, glossary keys and tests. Convert the sales screens' existing strings. Do not convert other roles' screens in this slice.

### Slice S2: Sales shell and navigation (section 3)
`SalesShell` with 4 tabs, `salesV2Enabled` flag, role isolation tests.

### Slice S3: Shop card with hisab strip and suggested order
**Where:** a bottom sheet that opens when a rep taps a shop in the list or a pin on the map; also the top of the shop profile screen. The strip sits directly under the shop name and class chip, above everything else.
**Hisab strip (one row of up to four tiles):** total due (`outstanding_paise`), credit left (`credit_limit_paise − outstanding_paise`, hidden for class D / NEW with 0 limit, replaced by a "Cash only" tile), days overdue and last payment date. **Show a tile only if real data exists.** If the app has no invoice due dates or payment history yet, show total due and credit left only, and do not show "days overdue" or "last payment". Traffic light: green when within limit and not overdue, amber when above 80% of limit, red when over limit or overdue; always with the word.
**Suggested order:** below the strip. Built from the shop's last 8 confirmed orders: for each product bought in at least 3 of those orders, suggest the typical (median) quantity per unit, capped by current available stock. Show the reason line ("Usually 2 peti every 7 days, last bought 9 days ago"). Each line has − qty + and an "Add all to cart" button. Fewer than 3 orders for the shop: hide the section and show "Order history will appear here". Deterministic rules only (no AI, no random). Add the existing "Repeat last order" next to it.
**Why:** a fresher gets a sensible order without experience; a senior saves time; the owner gets bigger, steadier orders.
**Tests:** hisab tiles appear only with data; traffic light thresholds; median suggestion math on a fixed fixture; stock cap; hidden under 3 orders; class D shows "Cash only".

### Slice S4: Collections, promises and cheques
**Where:** a "Collect" button on the shop card (next to "Take order"); a "Vasooli" filter chip in Shops listing shops with dues; a small reminder badge on Today for promises due today.
**Collect sheet:** amount (large keypad, rupees, converted to paise), mode (Cash / UPI / Cheque / Other), note. Part payment allowed. **Promise to pay:** "kab denge?" date picker, saved and shown on the shop card and as a reminder on that day's Today. **Post-dated cheque:** cheque number, bank name, cheque date, amount; reminder on cheque date.
**Rules:** records are saved in new additive tables (`collections`, `payment_promises`, `cheques`) with idempotency keys and a duplicate-tap guard. They stay local-only and honestly labelled "Saved on this phone, not yet sent" because the server does not handle them yet. UPI and cheque are labelled "Not verified". No edit or delete: only a reversal entry with a reason. Receipt is a localized text summary for sharing (see S5). Outstanding shown on the card must come from the existing ledger numbers; do not invent a new balance. If recording a collection cannot reduce the stored outstanding safely through the existing ledger logic, ask me how before implementing.
**Why:** udhaar, "kal dunga" and post-dated cheques are normal; the app must track them or reps go back to notebooks.
**Tests:** part payment; double-tap creates one record; promise reminder appears on the right day; cheque reminder; reversal; restart persistence.

### Slice S5: WhatsApp bill and day close
**Where:** after an order is saved ("Share bill" button on the success screen and in order history), after a collection ("Share receipt"), and on Earn → "Close day".
**Share:** you may add the `share_plus` package (system share sheet only, pinned to a version published at least two weeks ago). Say the exact version you pick and the reason. The bill text is in the shop's preferred language when known, otherwise the rep's current language: shop, date, items with units, total, payment mode, "Saved on this phone" status wording. Never claim the message was delivered or read.
**Day close:** one screen listing today's orders (count and booked value), collections recorded by mode, cash to hand over, visits done and missed with reasons, and tomorrow's first three shops. A "Share summary" button creates a text for the owner. It is labelled "From this phone".
**Tests:** text templates in all four languages contain correct numbers; no delivery claims; day-close totals equal the sum of the day's local records.

### Slice S6: Check before submit, outlier warning, polite credit stop
**Where:** the cart review screen; the "Book" buttons.
**Check screen:** one plain summary ("Kurkure 2 peti = ₹1,632") with two big buttons "Sahi hai" and "Badlo". Quantity outlier warning when a line is more than 3× the shop's typical (and at least 10 units): "Pehle 2 peti lete the. Ab 20 hai. Sahi hai?". Needs at least 3 past orders for that product, otherwise no warning.
**Credit stop:** when the order exceeds credit or the shop is class D / NEW, the credit buttons explain politely in the user's language and show "Owner se puchho". That creates a local approval request visible in the owner's existing approvals inbox on the same device only (no server). Label it "Request saved on this phone". Do not block cash orders.
**Why:** fewer silent mistakes from beginners, fewer arguments at the shop.
**Tests:** outlier thresholds; no warning with too little history; credit stop messaging; cash order allowed; owner inbox shows the request.

### Slice S7: Earn tab (honest version)
**Where:** third tab.
**v1 content (real local data only):** this week and this month: booked value, orders, visits, new shops added, collections recorded; a day-by-day bar of booked value. **Target and incentive:** show only if the owner has configured a target or plan; if not, show "Target not set by owner". No earnings amount is computed on the phone. Any number labelled "Estimated" must say it is not final pay.
**Why:** motivation and transparency; real pay will be calculated by the server later.
**Tests:** totals match fixture orders; no target shown without configuration.

### Slice S8: Today screen additions
- "Aaj ka kaam" list under the map: shops due for a visit (by class visit frequency from `class_settings` and days since last visit), ordered by class then days overdue; each row has a "Visit" button.
- Target ring only when a target exists.
- Morning card for focus products and schemes only when the owner has configured them; otherwise hidden. If no scheme or focus-product tables exist yet, say so in the report and do not create fake ones.

### Later slices (do NOT start; ask me first)
Voice order and voice notes, read-aloud, season mode, scheme-progress nudges (need a schemes data model and server support), incentive plan builder.

---

## 6. UI RULES FOR ALL NEW SALES SCREENS
- Reuse the existing `AirbnbTheme` tokens; no second design language.
- Icon plus short word on every action; one primary button per screen; the button the rep should press next is the largest.
- Status uses color plus word. Touch targets at least 48 dp, 130% text scale safe.
- Show "Saved on this phone" style honesty text in the user's language whenever data is not synced.
- Skeleton loaders, empty states with one clear action, plain-language errors, undo for removals.
- Never show raw ids, database terms, or infrastructure names.

---

## 7. REPORTS, PROCESS, DONE

After Step 0 and after each slice, report: files inspected, files changed (shared files listed separately with diffs), database changes, tests added with names, **raw pasted** last lines of `flutter analyze` and the full `flutter test`, `git log --oneline -5`, `git status`, and what you could not verify. Stop after each slice and wait for my "approved" only for S2 (navigation) and S4 (collections); the others may continue automatically if every gate passes. If a gate fails twice, stop and report.

Start now with section 1 (Step 0). Do not push. Do not touch remotes.
</USER_REQUEST>
<ADDITIONAL_METADATA>
The current local time is: 2026-11-05T00:10:35+05:30.
</ADDITIONAL_METADATA>