# Play closed test, Play Billing founding price, and Information Officer registration

**Date:** 2026-10-24 · **Author:** Claude for Tiaan · **Why:** prompt A after `reviews/2026-10-24-founder-pricing-full.md`. Wave 1 is sideloaded (D1); this note answers what the later move to Play and the POPIA registration involve.

Every figure has a source checked on 2026-10-24. **Not found** means no source said it.

---

## 1. Information Officer registration (POPIA)

| Question | Answer | Source |
|---|---|---|
| Cost | **Free.** The portal says all its services are "currently provided free of charge", and if that changes, affected parties "will be notified in advance" | [eServices portal, services](https://eservices.inforegulator.org.za/services.aspx) |
| Who | The head of a private body is the Information Officer by default; for a sole proprietorship that is the owner, so **Tiaan** | [Trinico (reviewed June 2026)](https://trinico.co.za/help/register-information-officer/), [ClearComply (26 May 2026)](https://www.clearcomply.co.za/blog/popia-information-officer-registration-south-africa); secondary sources, not the Regulator |
| Deadline | None now; the Regulator said parties would not be held liable for missing the original 30 June 2021 date | search snippet of the Regulator's guidance; not opened in full |
| Online steps | Create a user profile on eServices, log in, choose **Information Officers**, then **New Registration**. Enter the officer's full name, ID number, position and a **personal, direct email** (not `info@`). Add deputies if any (not needed here) | Regulator guide (snippet), [ClearComply](https://www.clearcomply.co.za/blog/popia-information-officer-registration-south-africa) |
| Catch for a sole proprietor | The online flow logs in with **CIPC customer-code credentials** and picks the entity from your CIPC records. A sole proprietor with no CIPC registration may not have an entity to pick. **Not found:** how the portal handles that | [ClearComply](https://www.clearcomply.co.za/blog/popia-information-officer-registration-south-africa) |
| Manual route (the fallback) | Download the registration form from inforegulator.org.za (Part A: Information Officer, Part B: deputies) and email it to `Registration.IO@inforegulator.org.za`. Acknowledgement within about **7 business days**, then a certificate with a reference number (no timeframe given) | [ClearComply](https://www.clearcomply.co.za/blog/popia-information-officer-registration-south-africa) |
| Time | Online: "minutes" to under 30 minutes | Trinico, ClearComply |
| After registering | Publish the Information Officer's contact details in the privacy policy | [Trinico](https://trinico.co.za/help/register-information-officer/) |

**Recommendation:** try the online flow first. If it insists on a CIPC entity, use the manual form by email, keep the acknowledgement, and record the reference number in STATUS. Then add the contact details to the privacy policy (`privacy-policy-site/`).

**Not checked:** the Regulator's own registration guide (`inforegulator.org.za/wp-content/uploads/2025/02/Registration.pdf`) is a scanned image and couldn't be read as text here. Open it before registering in case it differs from the secondary sources above.

---

## 2. Play closed test (for the later move to Play)

| Question | Answer | Source |
|---|---|---|
| Testing rule | Personal accounts created after 13 November 2023 "must run a closed test for their app with a minimum of 12 testers who have been opted in continuously for at least 14 days" | [Play Console Help](https://support.google.com/googleplay/android-developer/answer/14151465) |
| Then | Dashboard → **Apply for production**. The form has three parts (closed test, the app, production readiness). Review "typically" takes up to 7 days | same |
| Moving sideload testers to Play without a reinstall | Possible **only if the Play build is signed with the same key**. Play App Signing accepts your existing key ("Google Play now signs your app with your existing key"), and Google recommends supplying your own key when you want one key across stores. A different key means a different package name, and the user installs it "as a completely new app" | [Android Developers: app signing](https://developer.android.com/studio/publish/app-signing) |

**What that means for Piggybank:** when setting up Play App Signing, **upload the existing release key** (the one in `../ops/`; by name only) rather than letting Google generate one. Then the sideloaded wave 1 installs update in place from Play. If that is skipped, testers lose only on-device state (login, settings, the local review queue), because their financial data lives on the backend. They would still have to uninstall and reinstall.

**Timing, Estimate:** opening a Play account, 14 days of closed testing, then up to 7 days of review means about **3 weeks minimum** from the first 12 opted-in testers to production. Plan it back from the paid launch (Pro promo ends 28 Feb 2027 per `plans/founder-review-fixes.md`), so the closed test should start by about **early February 2027** at the latest.

---

## 3. Play Billing: the 12-month R29 founding price

| Question | Answer | Source |
|---|---|---|
| Can an offer cover 12 months at a lower price? | Yes. An introductory phase with **multiple payments** "provides a discount for between 1 and 52 recurrences of the base plan's billing period". A R49/month base plan with a R29 phase for **12 recurrences** gives the founding price; the price must be "the same as or lower than the base plan price" | [Play Console Help: offers](https://support.google.com/googleplay/android-developer/answer/12154973) |
| Can it be limited to beta testers and the first 50 payers? | Use **developer-determined** eligibility: "You solely decide the business logic and determine eligibility in your app". Play does not check it. The backend would flag eligible users (beta testers, first 50 payers) and the app would only show the offer to them. Such offers "cannot be purchased outside of your app" | same |
| Separate product ID needed? | No. A base plan plus an offer on the same subscription is enough | same; [Android Developers: subscriptions](https://developer.android.com/google/play/billing/subscriptions) |

**Not found:** whether a user who cancels mid-offer and resubscribes keeps the R29 price. The subscriptions page says a user who resubscribes to the same SKU is "no longer eligible for free trials or introductory price", which suggests **no**. State that in the founding-price terms.

---

## 4. Sideloading risks (D1)

Carried over from the founder review §7 and risk 10, not re-researched:
- Every tester installs an APK by hand (allow unknown sources, then manual updates).
- Android developer verification goes global on certified devices "in 2027". Unregistered apps will then need ADB or a 24-hour advanced flow. Register for verification on any route.
