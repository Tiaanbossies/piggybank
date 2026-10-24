# Piggybank 1.0.9+10: phone test checklist (device pass 2)

Build: `downloads/piggybank-latest.apk`, version 1.0.9+10, published 2026-10-13.
Goal: prove the build works for someone who is **not on the tailnet**, then confirm the QA pass 1 fixes on a real phone. Tick as you go; write what you saw next to anything that fails.

Drafted from the QA pass 1 notes and the PR descriptions (#66 to #76). Anything marked **(needs backend upgrade)** only works once the VPS is at alembic `99f23b1bebc5`.

---

## 0. Before you start (5 minutes, on the PC)

- [ ] **Backend is upgraded.** On 2026-10-13 13:13 SAST the VPS was still at #18 (alembic `a4528c75979a`). Redeploy and run `alembic upgrade head` so it reports `99f23b1bebc5`. Without this, sections 5 to 7 will fail for the wrong reason.
- [ ] `https://tiaanbossies-h81m-ds2.tail886b94.ts.net/api/health` returns `{"status":"ok",...}` from a browser **on the phone, on mobile data**.
- [ ] Do **not** change `BACKEND_BIND` yet. It stays as is until section 9 is done.

## 1. Install and update

- [ ] Phone: Tailscale **off**, Wi-Fi **off**, mobile data **on**. This is the whole point of the build.
- [ ] Install the new APK over the old one (or fresh). The app opens without a crash.
- [ ] If the old build was installed first: the **update banner** appeared before updating (build 9 sees build 10).
- [ ] Settings → About shows **Version 1.0.9** and a **built 13 Oct 2026** date, not a raw build number like 2010.
- [ ] No update banner after updating.

## 2. Public HTTPS connection (the new default)

- [ ] Sign in on mobile data with Tailscale off. It works.
- [ ] Home loads real data (not empty states, not a spinner that never ends).
- [ ] Pull to refresh works.
- [ ] Turn mobile data off, then on. The app recovers without a restart.
- [ ] Turn Wi-Fi back on. Still works.
- [ ] Optional: turn Tailscale on and confirm nothing breaks (the tailnet-IP fallback only fires when the HTTPS address fails at connection level).

## 3. Sign-in, lock and biometrics (PR6)

- [ ] Sign out, then sign back in with **fingerprint/face** (biometric login after logout).
- [ ] Wrong biometric falls back to password cleanly.
- [ ] Background the app past the lock timeout, return, and it asks to unlock.
- [ ] Biometric preference toggle in Settings persists after a restart.

## 4. QA pass 1 quick fixes (PR1)

- [ ] **Penny chat:** send a message. If it fails, the question and the error **stay on screen with Retry** (it must not drop back to the welcome screen). Note the exact error if you see one; the notes say to check Penny's real chat error on device.
- [ ] **Transaction sheet** has a Close (X). Start an entry, press X or system back, and it asks before discarding.
- [ ] **Home → recent transactions:** tapping one opens the transaction sheet.
- [ ] **Invest → top holdings:** tapping one opens the holding detail sheet.
- [ ] **Restore account:** archive an account, then restore it from the long-press menu and from the edit screen. Detail screen refreshes.
- [ ] **Liability detail:** log a payment. The list and net worth refresh, the "paid off" footnote comes from the balance, and delete-payment has the right tooltip.

## 5. Categories (PR3) (needs backend upgrade)

- [ ] Categories behave as in the PR3 description (learned categories apply to new transactions).
- [ ] Re-categorising one transaction sticks after a restart.

## 6. Pay-cycle months (PR4) (needs backend upgrade)

Rule: salary day 16 to 28 names the **next** month, day 2 to 15 names the **start** month, none or 1 is the calendar month.

- [ ] With salary day **25**, the period 25 Sep to 24 Oct is labelled **October**, everywhere (Home, budgets, reports).
- [ ] Budgets for that cycle show the same totals as the Transactions list for the same dates.
- [ ] Change the salary day to 5 and back. Labels follow the rule, nothing crashes.

## 7. Notifications inbox and salary detection (PR5, PR7) (needs backend upgrade)

- [ ] The **Home bell** opens a real inbox.
- [ ] An item can be opened, and marked read, and the bell badge updates.
- [ ] **Pro salary detect:** with a salary-like deposit, the app proposes the salary day (Pro account only).

## 8. Visual rework spot-check (release #65)

From the original capability inventory:

- [ ] Light theme: Home, Transactions, Invest, Net worth, Budgets all render with no clipped text.
- [ ] **Dark theme** on the same screens.
- [ ] **Reduced motion** (Android: Remove animations): the app is still usable and nothing is stuck mid-animation.
- [ ] Penny is the welcoming pose by default, and there is no Penny at rest on Home.
- [ ] Launcher icon shows the new welcoming Penny.
- [ ] Largest font size: nothing overlaps on Home or the add-transaction sheet.

## 9. Only after sections 1 to 8 pass for a few days

- [ ] Run it as your daily driver for a few days on mobile data.
- [ ] Then flip backend `BACKEND_BIND` to `127.0.0.1`. **Order matters:** doing it earlier cuts off the tailnet-IP fallback for any installed build.
- [ ] Re-run section 2 once more after the flip.

---

## Known open items (not part of this pass)

- `SMTP_*` is not set in the VPS `.env.docker`, so **password-reset emails won't send**. Don't test reset yet.
- Loans: schedule vs logged payments may double-count principal (`update_liability` / `log_payment`). Which is the source of truth is still undecided.
- RA unit-trust tracking is research only (#74). Expect no feature. The RA limit bug (R36k should be 27.5% capped at R350k/R430k from 2026-03-01) is logged there.

## Result

Date tested: ____  Phone/Android version: ____  Network: ____

Failures (section, what happened, screenshot):

1.
2.
3.
