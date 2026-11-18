# Notification capture audit (2026-10-24)

The app already reads banking-app push notifications. This note checks what is built against what SA banks and Android actually do. It looks for gaps and builds nothing new.

**Code checked:** branch `fix/founder-review-pr1` (`_worktrees/pb-app-pr1`, `_worktrees/pb-backend-pr1`).

**Research tools:** Firecrawl had no credits, so I used plain web search and page fetches. Every claim has one source. "Not found" means I looked and found nothing I could cite.

**Samples:** no real notifications or bank CSVs were used. The only samples quoted are the repo's own fake test strings.

---

## 1. The chain as built (confirmed against the code)

| Hop | Where | Notes |
|---|---|---|
| Listener | `android/.../DetectionNotificationListenerService.kt:41-65` | Steps, in order:<br>1. Package allowlist (`:43-44`).<br>2. Body from `EXTRA_BIG_TEXT`, else `EXTRA_TEXT`.<br>3. Title becomes the sender.<br>4. `rememberSeenSender`.<br>5. `DetectionFilter.verdict` (`:62`): sender checks drop; the amount-shape check only reports.<br>6. Enqueue.<br>Overrides only `onNotificationPosted`. |
| Queue | SharedPreferences `detection_notification_queue` / `queued_items` | Capped at 200 (oldest dropped); text capped at 4,000 characters. |
| Channel | `MainActivity.kt:23-62` | Handlers: peek (batch of 25, prunes first), ack, allowlist sync, seen senders, access check, open settings. |
| Upload | `notification_capture_service.dart:39-54`, triggered from `lib/app.dart:33,35,47` | **Foreground only**: on app start, on every resume, and every 15 minutes while the app is open. No WorkManager. |
| Ingest | `POST /api/detection/ingest/notifications` (`detection/router.py:253-320`) | Consent gate. Limits: 30 requests/min, 25 items per request. Items from packages not on the server-side allowlist are rejected and logged without their text. Returns 503 if Ollama isn't configured. |
| Extractor | `services/financial_event_extractor.py` | **One generic LLM prompt** (qwen2.5:3b, JSON mode, `:48-63`). No regex and no bank-specific code. `source_ref` and `sender` never pick a parser. Only `raw_text` goes to the model (`:351`). `validate_and_clean_event` (`:180-223`) rejects any event without an ISO `date`. |

**Tests:**
- `tests/test_detection_ingest_and_review.py` mocks the model. Its one bank package is `za.co.fnb.connect.itest`, and its sample text is "You spent R150.00 at Woolworths on 2026-09-15".
- `tests/test_financial_event_extractor.py` covers only the pure functions.
- **No real bank shape is tested for any of the nine banks.**

**Consequence:** "does the extractor parse bank X?" can't be answered from code. It depends on how qwen2.5:3b handles that bank's wording. Only the fixtures in PR 3 item 6, run as `@pytest.mark.live`, can answer it.

---

## 2. Per bank

How to read the columns:
- **Package:** "listing resolves" means `play.google.com/store/apps/details?id=…` returned a page rather than a 404. It has **not** been confirmed against a phone.
- **Parsed today:** "No sample" means no fixture exists, so it is unknown. It does not mean "fails".

| Bank | Android package | What its push shows | Parsed today? | Route for beta |
|---|---|---|---|---|
| FNB | `za.co.fnb.connect.itt` (listing resolves). The test fixture's `…itest` is not the real ID | Smart inContact sends an app notification for every transaction, whatever the amount [1]. **Amount/merchant wording: Not found** | No sample | Push; confirm with a sample |
| Capitec | `capitec.acuity.mobile.prod` (read off a phone, 2026-10-27) | Free in-app transaction notifications instead of SMS (40c each). Filter by Money In/Out, minimum R30 [2]. Card-limit changes still come by SMS [2]. **Wording: Not found** | No sample | Push; confirm with a sample |
| Absa | `com.barclays.absa.banking` (listing resolves) | Only in-app login and payment approvals are documented [3]. **Transaction push: Not found** | No sample | **SMS or CSV import only** until a sample shows an amount |
| Standard Bank | `com.sbg.mobile.phone` (listing resolves) | **Not found** (search only returned Standard Chartered) | No sample | **SMS or CSV import only** until a sample shows an amount |
| Nedbank | `za.co.nedbank` (listing resolves) | Real-time alerts in the Money app, "in-app and SMS". **No real-time alerts for debit orders, scheduled or batch payments** [4]. **Wording: Not found** | No sample | Push for card spend. Debit orders: CSV import only |
| Discovery | `bank.discovery.banking.production.release` [5] | Notifications are built into the app, and transaction and fraud notifications can't be silenced [6]. **Wording: Not found** | No sample | Push; confirm with a sample |
| Investec | `com.investec.app` (read off a phone, 2026-10-27) | Card transactions can be sent as in-app push instead of SMS: Menu → Settings → "Card transactions messages" [7]. **Wording: Not found** | No sample | Push for card spend, once the toggle is on |
| GoTyme (was TymeBank) | **Not found** (`za.co.tymebank` 404). TymeBank became GoTyme Bank on 22 Jan 2026, with a **new app** [8], so the old package may be dead | **Not found**. SendMoney credits are notified by SMS [9] | No sample | **SMS or CSV import only** until a sample shows an amount |

**Note on SMS:** "SMS" still goes through the same listener. The Messages app's notification is captured once the bank's sender is ticked, which is PR 1's sender filter. CSV import (`imports/`) is the fallback for everything.

---

## 3. Android limits for a sideloaded beta

| Limit | Affects us? | How a tester gets past it | What exists today |
|---|---|---|---|
| **Restricted settings (Android 13+).** Sideloaded apps are blocked from notification-listener access, and the toggle shows "Restricted setting" [10] | **Yes.** Every wave 1 tester on Android 13+ | 1. Try to turn on access once and get blocked.<br>2. Open App info → ⋮ → **Allow restricted settings** → confirm.<br>3. Turn access on.<br>The menu item only appears after the first blocked attempt [11]. | `NotificationAccessBanner` (`review_banner.dart:51-72`) already gives App info → ⋮ → Allow restricted settings. It doesn't say to try first. |
| **Enhanced Confirmation Mode (Android 15).** Replaces the Android 13 installer check with an allowlist of trusted installers. It covers notification listeners too [12] | **Probably yes**, but unconfirmed. The source says it wasn't switched on in Beta 1.1 and couldn't confirm the shipped behaviour [12] | Assume the same steps as above. Check on an Android 15 phone. | Same banner |
| **Sensitive notifications (Android 15).** Notifications holding a 2FA/OTP code reach untrusted listeners as "sensitive notification content hidden". Only system-signed apps, watch/glasses companions and the default launcher are exempt [13] | **Minor.** We'd discard OTPs anyway. Risk: a transaction alert that also carries a code arrives blank | Nothing; it can't be bypassed | Nothing needed. The placeholder text comes back `not_financial` |
| **OEM battery killers.** Huawei, Xiaomi, OnePlus and Samsung score worst (5/5) [14] | **Likely, on the commonest SA phones** (Samsung, Huawei, Xiaomi). Whether the system-bound listener itself gets killed: **Not found**, so it must be tested on a phone | Battery → **Unrestricted** for Piggybank. On Xiaomi, also turn on **Autostart** [14] | Nothing. No help text, no battery-settings link |
| **Listener unbound or disconnected.** The service can be unbound (app killed, updated, access toggled). `onListenerConnected`, `onListenerDisconnected` and `requestRebind(ComponentName)` exist for this [15] | **Yes.** We override none of them | Toggle notification access off and on | The access check (`MainActivity.kt:69-72`) only reads the Settings string, as a substring match on the package. "Access on but not delivering" goes unnoticed. Revocation is only caught on app resume. |

---

## 4. Gaps and the smallest fix for each

| # | Gap | Smallest fix | Lives in |
|---|---|---|---|
| G1 | **Every event needs a date, but bank pushes rarely carry one.** The model only sees `raw_text`, so it has to invent a date or the event becomes `skipped_invalid`. | Send `captured_at` with each item to the model. If the model's date is missing or unparseable, fall back to `captured_at` converted to Africa/Johannesburg. | Backend (`financial_event_extractor.py`) |
| G2 | No real bank shapes are tested, and the one fixture package (`…itest`) is not FNB's real ID. | PR 3 item 6 as written, plus the real package IDs and the date fallback case. | Backend tests |
| G3 | "Access on, listener not delivering" is invisible to the app. | Changes, in order:<br>1. `onListenerConnected` writes a timestamp to prefs.<br>2. `onListenerDisconnected` calls `requestRebind`.<br>3. `isNotificationListenerEnabled` also reports connection state.<br>4. The banner shows when access is granted but the service isn't connected. | App (Kotlin and banner) |
| G4 | The restricted-settings copy misses the "try first" step. | One sentence in `NotificationAccessBanner`: "Turn on notification access once. If it says Restricted, open App info → ⋮ → Allow restricted settings." | App |
| G5 | There's no battery-optimisation help. | A help line plus a button that opens `Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`. Opening that screen needs no permission. | App |
| G6 | Nedbank doesn't push debit orders in real time [4]. | No code. The new-debit-order alert (`plans/beta-stop-it-and-new-debit-alert.md`) should name CSV import as Nedbank's source. | Plan / docs |
| G7 | TymeBank → GoTyme app change [8]. | No code. Rename the bank in PR 3 item 6's list and confirm the new package from a phone. | Plan |
| G8 | Uploads only run in the foreground. A tester who doesn't open the app loses the oldest items once 200 are queued. | **Not now.** It's unlikely in a beta (200 items ≈ weeks). Revisit if the filter report shows drops. | App (WorkManager) |
| G9 | The access check is a substring match. A future `…piggybank.dev` flavour would read as enabled. | **Not now.** No such flavour exists. Fold it into G3, which can use `NotificationManager.isNotificationListenerAccessGranted(ComponentName)` instead. | App |

---

## 5. Open questions for Tiaan

1. **First fixture bank.** The plan says to start with your own bank. Is that Investec? If so, is the "Card transactions messages" push on? Can you supply 3 to 5 redacted push texts (amounts and merchants swapped out)?
2. **Package IDs.** Capitec, Investec and GoTyme are unconfirmed. Can you or a tester run `adb shell pm list packages | findstr -i "capitec investec tyme absa sbg nedbank discovery fnb"` on a phone with those apps installed? Package names only; no data leaves the phone.
3. **Date fallback (G1).** Is it fine for an undated notification to take the date it reached the phone (SAST)? A purchase late on a Sunday night that's pushed after midnight would land on Monday.
4. **Battery (G5).** Is a settings link enough? The alternative is asking for the exemption directly with `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, which Google Play restricts, so it would need undoing before the Play launch.
5. **Absa, Standard Bank and GoTyme.** Until a tester shows an amount in their push, should their testers be told up front to use SMS (by ticking the bank's sender) or CSV import?

## 6. Bank push setup (2026-10-27)

Package IDs were read with `adb shell pm list packages` on the test phone (Xiaomi 2201116TG, Android 13). They are also the quick-pick chips in Detection settings > Add app. "Verified on device" means a real transaction push was captured and extracted. Capitec is verified; Investec's SMS route is built but not yet captured on the phone.

| Bank | Package | Route | Verified on device |
|---|---|---|---|
| Nedbank | `za.co.nedbank` | Push for card spend. Debit orders come only through CSV import [4] | Package only |
| Investec | `com.investec.app` | SMS from a new number each time: add Messages, type "Investec" as a sender (it matches the name in the text). Card push needs Menu > Settings > "Card transactions messages" set to in-app push [7] | SMS text extracted correctly in the live test; the phone missed it with Autostart off |
| Capitec | `capitec.acuity.mobile.prod` | Push (Money In/Out; the app's minimum is R30) [2] | Yes, 2026-10-27: captured, extracted and confirmed in the review queue |
| Standard Bank | `com.sbg.mobile.phone` | Push if a sample shows an amount; otherwise SMS (tick the bank's sender) or CSV import | Package only |

Per-bank setup for a tester:

- **All banks:** add the bank under Detection settings > Add app, turn on notification access (on Android 13+, try once, then App info > ⋮ > Allow restricted settings), and set Battery to Unrestricted. On Xiaomi, also turn on Autostart.
- **Investec:** transfers and deposits come by SMS from a rotating number, so tick or type "Investec" under Messages; for card push, switch "Card transactions messages" to in-app push.
- **Nedbank:** card spend arrives by push; import debit orders from a CSV statement.
- **Standard Bank:** treat as SMS/CSV until a captured push shows an amount.

Status of the gaps on `feat/bank-push-capture`: G1, G3, G4, G5 and G9 are built; G2 has the date-fallback unit test, and the live per-bank fixtures wait on one real push per bank.

---

## Sources

1. FNB inContact (Smart inContact for every transaction): https://www.fnb.co.za/05includes/snippets/small/inContact.html and https://stuff.co.za/?p=88536
2. Capitec, transaction notifications: https://www.capitecbank.co.za/personal/transact/transaction-notifications-on-the-go/
3. Stitch, Absa MFA via in-app notification: https://support.stitch.money/hc/en-us/articles/7189440623377
4. Nedbank, transaction notifications: https://personal.nedbank.co.za/bank/digital-banking/needs/manage/transaction-notifications.html
5. Similarweb, Discovery Bank Android ID: https://similarweb.com/es/app/google/bank.discovery.banking.production.release
6. Discovery Bank, new app notifications (4 Oct 2021): https://www.discovery.co.za/bank/news-new-app-notifications
7. Investec, card transactions as in-app push: https://www.investec.com/en_za/focus/quick-update/do-more-on-your-phone-new-features-on-the-app.html
8. IOL, TymeBank evolves into GoTyme (4 Feb 2026): https://iol.co.za/business-report/companies/2026-02-04-tymebank-evolves-into-gotyme-enhancing-digital-banking-for-south-africans/ and https://en.wikipedia.org/wiki/GoTyme_Bank_(South_Africa)
9. GoTyme, SendMoney: https://gotyme.co.za/personal/media/money-skills-landing/send-cash-and-withdraw-on-your-mobile-with-gotyme-bank-sendmoney-services
10. Bayton, Android 13 restricted permissions: https://bayton.org/android/android-13-restricted-permissions/
11. CleanBrowsing, allow restricted settings: https://cleanbrowsing.org/support/mobile/disable-restricted-settings-android
12. Android Authority, Android 15 Enhanced Confirmation Mode (23 Apr 2024): https://androidauthority.com/android-15-enhanced-confirmation-mode-3436697
13. Android Authority, Android 15 hides 2FA codes from listeners (21 Oct 2024): https://www.androidauthority.com/android-15-two-factor-authentication-codes-3492585/
14. Don't kill my app, ranking: https://dontkillmyapp.com/
15. Android reference, NotificationListenerService: https://developer.android.com/reference/android/service/notification/NotificationListenerService. The fetched page was truncated before the method docs, so the method names come from the API, not from text read this session.

Google Play package checks were HTTP 404 versus page tests on `play.google.com/store/apps/details?id=…`, run 2026-10-24.
