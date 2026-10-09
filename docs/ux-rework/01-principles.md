# UX rework 01: principles digest

Session 1 of the Piggybank UX rework epic, written 2026-10-08. This is the reference
that the audit (`02-audit.md`) and the spec (`04-spec.md`, Session 2) cite by ID, for
example "K2" or "Y5".

**How this was built.** It comes from public sources only: lawsofux.com, nngroup.com,
nirandfar.com, Material Design, Android Developers, author summaries and reputable
reviews (listed at the end). Every rule is reworded in our own words, and no book text
is reproduced. Where a source is a secondary summary rather than the author's own site,
it is marked *(summary)*.

**Each entry has:**
- **Rule:** the principle in one line.
- **Finance app:** what it means for a personal-finance mobile app.
- **Piggybank check:** the question the audit and spec ask of every screen.

---

## Krug: *Don't Make Me Think* (K)

Core idea: every moment of "hmm, what do I do here?" is a cost, and costs add up on
something done daily.

| ID | Rule | Finance app | Piggybank check | Source |
|---|---|---|---|---|
| K1 | Make each screen self-evident. If that's impossible, make it self-explanatory, with no puzzling. | Money already causes anxiety, so ambiguity feels like risk. A label like "Detection" or "Snapshot" makes people stop and decode. | Can a first-time user say what this screen is for, and what to do, within ~3 seconds and without reading paragraphs? | [blas.com (summary)](https://blas.com/dont-make-me-think/), [Helios Design](https://www.heliosdesign.com/blog/web/insights-from-dont-make-me-think-by-steve-krug.html) |
| K2 | People scan; they don't read. Design for a glance: clear hierarchy, few words, obvious tap targets. | The daily open is a 5-second glance, not a session. The one number that matters has to be the biggest thing on screen. | On a 2-second glance at Home, what do your eyes land on, and is it the thing that changed today? | [Readingraphics (summary)](https://readingraphics.com/book-summary-dont-make-me-think/) |
| K3 | Tap count matters less than certainty. Three obvious taps beat one confusing one. | Moving "Review" one level deeper costs less than labelling it ambiguously. | For each core task, is every tap an unambiguous choice, or is any step a guess? | [Readingraphics (summary)](https://readingraphics.com/book-summary-dont-make-me-think/) |
| K4 | Use conventions. Only break one when the replacement is either instantly clear or worth a learning curve. | Finance apps have trained users: balance at top, a transaction feed, and a + for adding. | Where we break a finance-app or Material convention, is it clearly better? | [blas.com (summary)](https://blas.com/dont-make-me-think/) |
| K5 | Omit needless words. Cut happy talk and instructions nobody reads. | Disclaimers and explanations belong one tap away, not in the daily path. | Can any line of copy on this screen be deleted without anyone missing it? | [Readingraphics (summary)](https://readingraphics.com/book-summary-dont-make-me-think/) |
| K6 | The **trunk test**: dropped onto any screen, a user should be able to tell which app this is, which screen they're on, where they can go, and how to get back. | Deeply pushed screens (Policy → Ask Penny, Settings → Detection → Review) are where people get lost. | On every pushed screen: is the title specific, is the back path obvious, and does the nav show where we are? | [Helios Design](https://www.heliosdesign.com/blog/web/insights-from-dont-make-me-think-by-steve-krug.html), [MATHguide](https://www.mathguide.com/services/Design/Laws3.html) |
| K7 | Test with a few real users, often. Watching beats asking. | Three family members doing five tasks on a real phone will find more than any checklist. | Has this flow been watched on a real phone by someone who didn't build it? | [Helios Design](https://www.heliosdesign.com/blog/web/insights-from-dont-make-me-think-by-steve-krug.html) |

## Norman: *The Design of Everyday Things* (N)

Core idea: errors are design failures. Bridge the gap between what the user wants and
what the interface offers (execution), and between what happened and what the user
perceives (evaluation).

| ID | Rule | Finance app | Piggybank check | Source |
|---|---|---|---|---|
| N1 | **Affordances and signifiers.** What can be done must also be *visibly* signalled. A hidden gesture only works if something shows it exists. | Swipe-to-confirm on the review queue is powerful but invisible; it needs a visible button too, or a hint the first time. | Does every gesture-only action also have a visible control or a one-time hint? | [Parker Klein notes](https://www.parkerklein.com/notes/the-design-of-everyday-things), [UX Mag](https://uxmag.medium.com/understanding-don-normans-principles-of-interaction-6dffdb2287b1) |
| N2 | **Mapping.** Controls should sit near, and look like, what they affect. | Edit and Delete on a row belong to that row, and a month chevron belongs next to the month it changes. | Is each control next to the thing it changes? | [h-da HCI material](https://hci-trapp.h-da.io/hci-material/theory/intro/) |
| N3 | **Feedback.** Every action needs an immediate, readable response. Without one, people retry or lose trust. | After Confirm or Save, the user must *see* the result: the row leaves, the total updates, a snackbar appears. Money actions without feedback get done twice. | After every primary action, what changes on screen within 100 ms? | [Parker Klein notes](https://www.parkerklein.com/notes/the-design-of-everyday-things) |
| N4 | **Constraints.** Make wrong actions impossible or hard instead of warning about them afterwards. | Use a decimal keypad for amounts, and disable Save until the form is valid. Disabling biometrics with no PIN is already constrained this way. | Can a user produce a bad record (no account, wrong sign, empty category) from this screen? | [Parker Klein notes](https://www.parkerklein.com/notes/the-design-of-everyday-things) |
| N5 | **Conceptual model.** The user needs a simple, true story of how the system works. | "Your bank texts arrive → Piggybank suggests a category → you confirm" is the model, and every screen should reinforce it. Today it's split between Settings → Detection and Home. | Can a user explain where transactions come from and what "review" means, after a week of use? | [UX Mag](https://uxmag.medium.com/understanding-don-normans-principles-of-interaction-6dffdb2287b1) |
| N6 | **Gulf of execution.** Shrink the distance between intent ("log this coffee") and the available action. | The FAB on Home closed most of this gap in 1.0.6. | For each core intent, how far is the action from where the user is when the intent arises? | [NN/g: The Two UX Gulfs](https://www.nngroup.com/articles/two-ux-gulfs-evaluation-execution/) |
| N7 | **Gulf of evaluation.** Make system state obvious: did it work, what's the state now, is everything OK? | "Am I on track this month?" should be readable without arithmetic. | Can the user tell whether they're OK this month without adding anything up themselves? | [NN/g: The Two UX Gulfs](https://www.nngroup.com/articles/two-ux-gulfs-evaluation-execution/) |
| N8 | **Design for error.** Slips are normal. Make actions reversible (undo beats "Are you sure?"), and never make people start over. | Undo on review discard is right. Deleting a transaction or account should prefer undo over a dialog where it can. | Does each destructive action have undo, or at least a clear preview of its effect? | [Parker Klein notes](https://www.parkerklein.com/notes/the-design-of-everyday-things) |
| N9 | **Knowledge in the world, not in the head.** Show the options; don't make people remember where things live. | Users shouldn't have to remember that Review lives under Settings. | What does the user have to *remember* to do the core loop? | [Parker Klein notes](https://www.parkerklein.com/notes/the-design-of-everyday-things) |

## Yablonski: *Laws of UX* (Y)

Definitions paraphrased from lawsofux.com. The site is public, and each law has its own page.

| ID | Law | Finance app | Piggybank check | Source |
|---|---|---|---|---|
| Y1 | **Jakob's law.** Users expect your app to work like the others they use. | Bank apps put the balance or feed first and a bottom tab bar under the thumb, so Piggybank should feel familiar to a Capitec, FNB or TymeBank user. | Does this screen behave like the equivalent screen in the user's banking app? | [lawsofux.com/jakobs-law](https://lawsofux.com/jakobs-law/) |
| Y2 | **Hick's law.** Decision time grows with the number and complexity of choices. | Home's quick-link grid, five tabs, a long Settings list: each adds decision time to the daily open. | How many choices are visible at the decision point, and can the daily ones be separated from the rare ones? | [lawsofux.com/hicks-law](https://lawsofux.com/hicks-law/) |
| Y3 | **Fitts's law.** Big, close targets are faster to hit. | Primary actions (Add, Confirm) should be large and in the lower thumb zone, not in a top-right icon. | Is the most frequent action the biggest, most reachable target? | [lawsofux.com/fittss-law](https://lawsofux.com/fittss-law/), [Hoober, UXmatters](https://www.uxmatters.com/mt/archives/2013/02/how-do-users-really-hold-mobile-devices.php) |
| Y4 | **Miller's law / chunking.** Working memory is small, so group information into meaningful chunks. | Transactions grouped by day, and settings grouped by purpose. | Are long lists chunked under headings a user would use themselves? | [lawsofux.com/millers-law](https://lawsofux.com/millers-law/), [lawsofux.com/chunking](https://lawsofux.com/chunking/) |
| Y5 | **Doherty threshold.** Keep response under ~400 ms so neither side waits. | Optimistic UI on confirm and add; skeletons rather than spinners for slow API calls. | Does every tap respond visibly in under 400 ms, even when the network is slow? | [lawsofux.com/doherty-threshold](https://lawsofux.com/doherty-threshold/), [NN/g response limits](https://www.nngroup.com/articles/response-times-3-important-limits/) |
| Y6 | **Tesler's law.** Some complexity can't be removed, only moved. The system should absorb it, not the user. | Categorising is irreducible. Auto-capture plus learned suggestions move it onto Piggybank. | Who is carrying this complexity, the user or the app? | [lawsofux.com/teslers-law](https://lawsofux.com/articles/2024/teslers-law/) |
| Y7 | **Peak-end rule.** Experiences are judged by their high point and how they end. | The daily loop should *end* well: "All caught up", not a dead empty list. | What does the user see at the end of the daily loop? | [lawsofux.com/peak-end-rule](https://lawsofux.com/peak-end-rule/) |
| Y8 | **Goal-gradient effect.** Effort rises as people get closer to a goal. | Progress toward the savings gap and goals motivates more as it nears 100%, so make the remaining distance visible. | Does every goal-like number show how far is left, not only how far has come? | [lawsofux.com/goal-gradient-effect](https://lawsofux.com/goal-gradient-effect/) |
| Y9 | **Zeigarnik effect.** Unfinished tasks stick in memory. | "3 to review" is a legitimate open loop that brings people back. Leave it open honestly; never invent fake unfinished tasks. | Is any "unfinished" signal real, and does it clear once done? | [lawsofux.com/zeigarnik-effect](https://lawsofux.com/zeigarnik-effect/) |
| Y10 | **Serial position effect.** First and last items are remembered best. | In the bottom nav, the first and last tabs are the strongest positions. Home first is right; is Settings worth the last slot? | Are the most important destinations at the ends of lists and nav bars? | [lawsofux.com/serial-position-effect](https://lawsofux.com/serial-position-effect/) |
| Y11 | **Von Restorff effect.** The one thing that differs gets noticed. | Over-budget red works *because* red is rare (DESIGN.md already reserves it). One accent CTA per screen. | Is exactly one element visually distinct on each screen, and is it the right one? | [lawsofux.com/von-restorff-effect](https://lawsofux.com/von-restorff-effect/) |
| Y12 | **Proximity, common region, similarity.** Things near each other, sharing a container, or looking alike read as related. | The row-card system gives this for free, provided unrelated things aren't put in the same card. | Do visual groupings match conceptual groupings? | [lawsofux.com/law-of-proximity](https://lawsofux.com/law-of-proximity/), [lawsofux.com/law-of-common-region](https://lawsofux.com/law-of-common-region/) |
| Y13 | **Aesthetic-usability effect.** Attractive interfaces are perceived as easier to use, and can hide real problems in testing. | Polish earns tolerance, but don't let it mask a broken flow in the critique. | Is this screen actually easy, or just pretty? | [lawsofux.com/aesthetic-usability-effect](https://lawsofux.com/aesthetic-usability-effect/) |
| Y14 | **Choice overload.** Too many options overwhelms. | A full category list on every add is overload; the top-6 chips plus "More…" (shipped) is the fix pattern. | Where are we showing every option when 5 would do? | [lawsofux.com/choice-overload](https://lawsofux.com/choice-overload/) |
| Y15 | **Pareto principle.** Most use comes from a few features. | Likely: today's spend, review, add, budget check. These get prime real estate; Calculators, Import and RA/TFSA get a quieter home. | Is screen space allocated in proportion to use frequency? | [lawsofux.com/pareto-principle](https://lawsofux.com/pareto-principle/) |
| Y16 | **Paradox of the active user.** Nobody reads instructions; people start tapping. | Onboarding and empty states must teach by doing, not by text walls. | Can a new tester reach first value without reading anything? | [lawsofux.com/paradox-of-the-active-user](https://lawsofux.com/paradox-of-the-active-user/) |
| Y17 | **Mental model.** People bring a compressed model from elsewhere. | Users think in "money in / money out / what's left", not in "liabilities / assets / snapshot". | Do our labels match the user's words or our data model's? | [lawsofux.com/mental-model](https://lawsofux.com/mental-model/) |
| Y18 | **Postel's law.** Accept messy input generously, and output clean, consistent results. | Amount fields should accept "45", "45.0", "R45" and "45,00" (SA locale uses comma decimals). | Does every input accept the forms a South African would naturally type? | [lawsofux.com/postels-law](https://lawsofux.com/postels-law/) |

## Tidwell: *Designing Interfaces* (T)

Pattern names come from the book's public table of contents and summaries. Each
description here is our own paraphrase.

| ID | Pattern | Finance app | Piggybank check | Source |
|---|---|---|---|---|
| T1 | **Safe exploration.** Let people poke around without fear of breaking or losing anything. | Undo, non-destructive defaults, and drafts kept if a sheet is dismissed by accident. | Can a user explore any screen with zero risk of an unintended money record? | [Ferreira (summary)](https://medium.com/@mariliaferreira/14-behavioral-patterns-for-user-interface-design-f08c5034ef83) |
| T2 | **Instant gratification.** Value in the first seconds. | The first open after auto-capture should already show something useful (today's spend, new items). | How many seconds from cold open to the first useful number? | [Ferreira (summary)](https://medium.com/@mariliaferreira/14-behavioral-patterns-for-user-interface-design-f08c5034ef83) |
| T3 | **Satisficing.** People pick the first reasonable option, not the best one. | The first plausible-looking button gets tapped, so make the first plausible one the right one. | Is the most prominent action on each screen the one most users want? | [Ferreira (summary)](https://medium.com/@mariliaferreira/14-behavioral-patterns-for-user-interface-design-f08c5034ef83) |
| T4 | **Deferred choices.** Don't demand optional input up front. | Add only needs amount + category; account defaults, and notes are optional and collapsed. | Which fields could be defaulted or deferred? | [Ferreira (summary)](https://medium.com/@mariliaferreira/14-behavioral-patterns-for-user-interface-design-f08c5034ef83) |
| T5 | **Microbreaks.** Design for 30-second sessions squeezed between other things. | The core loop is a queue-standing, 30-second task. | Can the whole daily loop be done in one microbreak, with state kept if interrupted? | [Ferreira (summary)](https://medium.com/@mariliaferreira/14-behavioral-patterns-for-user-interface-design-f08c5034ef83) |
| T6 | **Habituation and spatial memory.** People remember *where* things are, and muscle memory forms. | Moving things around breaks habit, so the rework must settle locations once and keep them stable. | After the rework, will each daily action stay in the same place for the long term? | [Ferreira (summary)](https://medium.com/@mariliaferreira/14-behavioral-patterns-for-user-interface-design-f08c5034ef83) |
| T7 | **Prospective memory.** Help people remember to do things later. | A "3 to review" badge, savings-plan cut reminders, and bill due dates are honest reminders. | Does the app hold the "remember to…" so the user doesn't have to? | [Ferreira (summary)](https://medium.com/@mariliaferreira/14-behavioral-patterns-for-user-interface-design-f08c5034ef83) |
| T8 | **Streamlined repetition.** Make frequent repeated actions cheap. | One-tap confirm, last-used account, and learned categories (all shipped) are this pattern. | Which daily action still repeats a choice the app could remember? | [Ferreira (summary)](https://medium.com/@mariliaferreira/14-behavioral-patterns-for-user-interface-design-f08c5034ef83) |
| T9 | **Bottom navigation.** On mobile, top-level destinations sit in a persistent bottom bar, keeping the top of the screen for content. | Already used. The question is *which* five destinations earn a slot. | Does each tab earn its slot by daily or weekly use? | [Tidwell 3rd ed., O'Reilly](https://www.oreilly.com/library/view/designing-interfaces-3rd/9781492051954/), [Material 3 nav bar](https://m3.material.io/components/navigation-bar/guidelines) |
| T10 | **Prominent "Done" button / assumed next step.** The action that finishes a task is unmistakable and sits at the end of the eye's path. | Save, Confirm and Set target: one per sheet, filled, at the bottom in the thumb zone. | Is the finishing action of every sheet/form the single most prominent control, at the bottom? | [Tidwell 3rd ed., O'Reilly](https://www.oreilly.com/library/view/designing-interfaces-3rd/9781492051954/) |
| T11 | **Good defaults and smart prefills.** Pre-fill what you can reasonably guess. | Date = today, account = last used, category = suggestion, and type inferred from the sign. | Which fields on this form start empty but could be prefilled? | [Tidwell 3rd ed., O'Reilly](https://www.oreilly.com/library/view/designing-interfaces-3rd/9781492051954/) |
| T12 | **One-window drilldown and list/detail.** On a phone, a list opens a detail view and back returns to the same scroll position. | Transactions → detail sheet; Savings → Policy. | Does back always return to exactly where the user was? | [Tidwell 3rd ed., O'Reilly](https://www.oreilly.com/library/view/designing-interfaces-3rd/9781492051954/) |
| T13 | **Dashboard.** One screen with the few key indicators, each drilling down. | Home is a dashboard: show the 3–4 indicators that change daily and link every one to its detail. | Does every figure on Home drill into its explanation? | [Tidwell 3rd ed., O'Reilly](https://www.oreilly.com/library/view/designing-interfaces-3rd/9781492051954/) |

## Eyal: *Hooked*, and the Manipulation Matrix (H)

Core idea: habits form through repeated passes of **trigger → action → variable reward
→ investment**, until an internal trigger (a feeling) replaces the external one. The
ethics check comes first.

| ID | Rule | Finance app | Piggybank check | Source |
|---|---|---|---|---|
| H0 | **Manipulation Matrix: answer it before building any hook.** Two questions: would the maker use it, and does it materially improve the user's life? Yes/yes is a *facilitator*. Yes to improvement but no to use is a *peddler* (usually fails). Use without improvement is an *entertainer*, and neither is a *dealer*. | Tiaan uses Piggybank daily, and the aim (afford rent, see spending) is material, so the product is a facilitator. **Each individual hook** still has to pass on its own. A guilt notification fails even inside a facilitator product. | For each hook: would Tiaan want it on his own phone, and does it help the user's money, not just engagement numbers? | [nirandfar.com: The Morality of Manipulation](https://www.nirandfar.com/the-art-of-manipulation/) |
| H1 | **External triggers** start the loop: a notification, an icon, a badge. They should promise real value. | A real one: "3 new transactions captured, tap to confirm". A fake one: "We miss you!" | Does every notification carry information the user would want even without opening the app? | [nirandfar.com: Hooked Model](https://www.nirandfar.com/how-to-manufacture-desire/) |
| H2 | **Internal triggers** are the goal: a feeling ("did I overspend?", "what's left till payday?") that sends the user to the app unprompted. | The internal trigger for Piggybank is money uncertainty after a purchase or near month-end. | Which feeling sends a user here, and does Home answer *that* feeling first? | [nirandfar.com: Hooked Model](https://www.nirandfar.com/how-to-manufacture-desire/) |
| H3 | **Action** has to be the simplest behaviour that leads to the reward, so lower the effort before raising motivation. (Eyal draws on Fogg's behaviour model here.) | The open → confirm path has to be one tap per item, which is already shipped. | Is the action between trigger and reward as small as it can be? | [nirandfar.com: Hooked Model](https://www.nirandfar.com/how-to-manufacture-desire/), [behaviormodel.org](https://behaviormodel.org/) |
| H4 | **Variable reward.** Predictable feedback doesn't build desire, but some variability does. Eyal's three kinds are the tribe (social), the hunt (resources/information) and the self (mastery). | Ethical variability for a money app is information that genuinely differs day to day: today's spend vs a normal day, "you spent R120 less on takeaways this week", a newly detected recurring cost worth cutting, the gap shrinking. Never slot-machine mechanics. | Is the "reward" real new information about the user's own money, rather than random novelty or confetti? | [nirandfar.com: Hooked Model](https://www.nirandfar.com/how-to-manufacture-desire/), [Amplitude (summary)](https://amplitude.com/blog/the-hook-model) |
| H5 | **Investment.** The user puts something in that makes the next loop better: data, preferences, effort. | Each confirmation teaches category suggestions, and targets, goals, cut decisions and policies make Penny and the savings plan smarter. Saying so outright ("Piggybank learned 'Woolies → Groceries'") makes the investment visible. | After the reward, does the user leave something behind that improves tomorrow's loop, and can they see it pay off? | [nirandfar.com: Hooked Model](https://www.nirandfar.com/how-to-manufacture-desire/) |

### Guardrails for money apps (dark patterns to avoid)

These rules are binding on the spec, and DESIGN.md already bans confetti, streaks and
badges.

- **No confirmshaming or guilt copy** ("Still haven't checked your budget?"). Guilt-based
  persuasion is a documented dark pattern in financial UX.
  ([UXDA](https://theuxda.com/blog/dark-patterns-in-digital-banking-compromise-financial-brands),
  [Finance Watch](https://www.finance-watch.org/blog/dark-patterns-explained-how-to-spot-and-avoid-deceptive-ux/))
- **No punishing streaks.** A missed day must never reset or shame. If continuity is
  shown at all, show it as a positive count that pauses rather than breaks.
- **No fake urgency or fake open loops.** Badges show real pending work only.
- **Notifications are opt-in per type,** and the existing Notifications settings screen
  is the control surface.
- **The FTC has documented the rise of dark patterns** that trick consumers, so
  regulators are watching this space.
  ([FTC 2022](https://www.ftc.gov/news-events/news/press-releases/2022/09/ftc-report-shows-rise-sophisticated-dark-patterns-designed-trick-trap-consumers))

---

## Platform constraints (P)

| ID | Rule | Piggybank check | Source |
|---|---|---|---|
| P1 | A bottom nav bar holds **3–5** destinations. | No more than 5 tabs, each earning its place. | [Material 3 nav bar](https://m3.material.io/components/navigation-bar/guidelines), [Material 2 bottom nav](https://m2.material.io/components/bottom-navigation) |
| P2 | Hidden navigation (drawers, hamburger menus) cuts discoverability sharply. Use it only for rarely used items. | Nothing daily lives behind a menu. | [NN/g: Mobile navigation patterns](https://www.nngroup.com/articles/mobile-navigation-patterns/), [NN/g: Hamburger discoverability](https://www.nngroup.com/articles/find-navigation-mobile-even-hamburger/) |
| P3 | Touch targets of at least **48×48 dp**, with about 8 dp between them. | Every icon button, chip and row action. | [Android Developers: accessibility](https://developer.android.com/guide/topics/ui/accessibility/apps), [Android Accessibility Help](https://support.google.com/accessibility/android/answer/7101858?hl=en) |
| P4 | Most phone use is one-handed and thumb-driven, and the lower-middle screen is easiest to reach. | Primary actions sit in the bottom half. | [Hoober, UXmatters](https://www.uxmatters.com/mt/archives/2013/02/how-do-users-really-hold-mobile-devices.php), [Parachute (summary)](https://parachutedesign.ca/blog/thumb-zone-ux/) |
| P5 | Response limits: **0.1 s** feels instant, **1 s** keeps flow, and **10 s** loses attention. | Taps at 0.1 s, navigation under 1 s, and anything longer shows progress. | [NN/g: Response time limits](https://www.nngroup.com/articles/response-times-3-important-limits/) |

---

## How finance apps handle navigation and the daily loop

These are observed patterns, cited as such. They are inputs to the spec, not targets
to copy.

- **Copilot Money: a "since you last opened" review loop.** On open, the dashboard
  highlights transactions that arrived since the last visit, grouped by day. Each is
  marked reviewed with one tap, which the reviewer estimates covers about 80% of items
  unchanged. Recategorising takes a few seconds. Notifications cover new transactions to
  categorise, payday and suspected fraud. The reviewer, a former UX professional,
  reports it as one of their most-used apps.
  ([Money with Katie review](https://moneywithkatie.com/copilot-review-a-budgeting-app-that-finally-gets-it-right/))
  → *This is the same loop as Piggybank's pending review. The difference is that it is
  the **first** thing on open, not a card further down.*
- **Monzo / Revolut: the feed is the home screen.** Monzo rebuilt Home as a single
  unified activity feed across all accounts, with account badges and deduplicated
  transfers. It popularised instant spend notifications, so the payment notification
  *is* the trigger.
  ([Monzo blog: unified home feed](https://monzo.com/blog/how-we-unified-our-customers-activity-on-the-new-home-screen),
  [Monzo: 15 features](https://monzo.com/blog/2019/10/24/15-features-thatll-turn-monzo-sceptics-into-monzo-obsessives))
  → *Recent activity belongs high on Home, with dates.*
- **YNAB: engagement through a "today" glance.** A public YNAB concept case study
  centres on a Today-view widget. Its premise is that keeping the budget glanceable
  outside the app keeps it top of mind and stops transactions being missed. Reviewers
  describe YNAB's daily categorising as friction that changes behaviour, but also as a
  chore people abandon.
  ([Berkompas YNAB concept](https://medium.com/@benberkompas/a-new-concept-for-ynab-2774027cca88),
  [Beancount forum comparison](https://beancount.io/forum/t/copilot-vs-monarch-vs-ynab-which-premium-budget-app-is-worth-it/98),
  [OpenBudget comparison](https://www.openbudget.sh/blog/best-budgeting-apps-in-2026-ynab-vs-copilot-vs-monarch-vs-openbudget))
  → *Piggybank should be friction-light, as Copilot is, while keeping one moment of
  conscious contact per transaction (the confirm), which is the useful part of YNAB's
  friction. A home-screen widget is a candidate for later.*

**Gap:** we found no strong public write-up from South African banking apps (Capitec,
TymeBank, Discovery Bank) on their navigation rationale. Jakob's law (Y1) still points
at them as the convention Piggybank's users know. Check this by hand in the audit
rather than assuming.

---

## The ten questions every spec decision must answer

A condensed checklist for Session 2. Each spec decision cites at least one ID.

1. Is the screen's purpose and its one primary action obvious at a glance? (K1, K2, T3, Y11)
2. Is every tap in the core loop an unambiguous choice? (K3, N6)
3. Does Home answer "am I OK today and this month?" without arithmetic? (N7, H2, T13)
4. Is the daily loop doable in one 30-second microbreak, ending in "all caught up"? (T5, Y7)
5. Are daily actions large, low, and in the thumb zone? (Y3, P3, P4)
6. Does every action give feedback within 100–400 ms? (N3, Y5, P5)
7. Is every destructive action undoable? (N8, T1)
8. Are frequent choices remembered or prefilled? (T8, T11, Y6)
9. Does each tab earn its place by frequency of use, and are rare features kept out of the daily path without being hidden? (Y2, Y15, T9, P1, P2)
10. Does every hook pass the Manipulation Matrix and the guardrails above? (H0–H5)

## Sources

Our own reads were full scrapes of lawsofux.com (index), nirandfar.com (Morality of
Manipulation, Hooked Model), NN/g (Two Gulfs) and the Money with Katie review. The other
sources were read as search excerpts.

1. [Laws of UX: Jon Yablonski](https://lawsofux.com/): the public definitions of all laws cited (Y1–Y18)
2. [Nir Eyal: The Morality of Manipulation](https://www.nirandfar.com/the-art-of-manipulation/): the Manipulation Matrix
3. [Nir Eyal: The Hooked Model](https://www.nirandfar.com/how-to-manufacture-desire/): trigger, action, variable reward, investment
4. [Amplitude: The Hook Model](https://amplitude.com/blog/the-hook-model): a summary of the variable-reward types
5. [NN/g: The Two UX Gulfs](https://www.nngroup.com/articles/two-ux-gulfs-evaluation-execution/): execution and evaluation
6. [NN/g: Response Times: The 3 Important Limits](https://www.nngroup.com/articles/response-times-3-important-limits/)
7. [NN/g: Basic Patterns for Mobile Navigation](https://www.nngroup.com/articles/mobile-navigation-patterns/)
8. [NN/g: Making navigation discoverable on mobile](https://www.nngroup.com/articles/find-navigation-mobile-even-hamburger/)
9. [Parker Klein: notes on The Design of Everyday Things](https://www.parkerklein.com/notes/the-design-of-everyday-things): reading notes
10. [UX Magazine: Understanding Don Norman's principles](https://uxmag.medium.com/understanding-don-normans-principles-of-interaction-6dffdb2287b1)
11. [h-da: Introduction to HCI](https://hci-trapp.h-da.io/hci-material/theory/intro/): university course material on the gulfs and mapping
12. [The Rabbit Hole: Don't Make Me Think notes](https://blas.com/dont-make-me-think/)
13. [Readingraphics: Don't Make Me Think summary](https://readingraphics.com/book-summary-dont-make-me-think/)
14. [Helios Design: insights from Don't Make Me Think](https://www.heliosdesign.com/blog/web/insights-from-dont-make-me-think-by-steve-krug.html)
15. [MATHguide: the trunk test](https://www.mathguide.com/services/Design/Laws3.html)
16. [O'Reilly: Designing Interfaces, 3rd ed. (Tidwell, Brewer, Valencia)](https://www.oreilly.com/library/view/designing-interfaces-3rd/9781492051954/): pattern names
17. [Marilia Ferreira: 14 behavioural patterns from Designing Interfaces](https://medium.com/@mariliaferreira/14-behavioral-patterns-for-user-interface-design-f08c5034ef83)
18. [Material 3: Navigation bar guidelines](https://m3.material.io/components/navigation-bar/guidelines)
19. [Material 2: Bottom navigation](https://m2.material.io/components/bottom-navigation)
20. [Android Developers: Make apps more accessible](https://developer.android.com/guide/topics/ui/accessibility/apps)
21. [Android Accessibility Help: Touch target size](https://support.google.com/accessibility/android/answer/7101858?hl=en)
22. [Steven Hoober: How do users really hold mobile devices?](https://www.uxmatters.com/mt/archives/2013/02/how-do-users-really-hold-mobile-devices.php)
23. [Parachute Design: the thumb zone](https://parachutedesign.ca/blog/thumb-zone-ux/)
24. [Money with Katie: Copilot Money review](https://moneywithkatie.com/copilot-review-a-budgeting-app-that-finally-gets-it-right/)
25. [Monzo: unified home feed](https://monzo.com/blog/how-we-unified-our-customers-activity-on-the-new-home-screen)
26. [Monzo: 15 features](https://monzo.com/blog/2019/10/24/15-features-thatll-turn-monzo-sceptics-into-monzo-obsessives)
27. [Ben Berkompas: a Today-view concept for YNAB](https://medium.com/@benberkompas/a-new-concept-for-ynab-2774027cca88)
28. [Beancount forum: Copilot vs Monarch vs YNAB](https://beancount.io/forum/t/copilot-vs-monarch-vs-ynab-which-premium-budget-app-is-worth-it/98)
29. [OpenBudget: budgeting apps in 2026](https://www.openbudget.sh/blog/best-budgeting-apps-in-2026-ynab-vs-copilot-vs-monarch-vs-openbudget)
30. [UXDA: dark patterns in banking UX](https://theuxda.com/blog/dark-patterns-in-digital-banking-compromise-financial-brands)
31. [Finance Watch: dark patterns explained](https://www.finance-watch.org/blog/dark-patterns-explained-how-to-spot-and-avoid-deceptive-ux/)
32. [FTC: rise of sophisticated dark patterns (2022)](https://www.ftc.gov/news-events/news/press-releases/2022/09/ftc-report-shows-rise-sophisticated-dark-patterns-designed-trick-trap-consumers)
33. [BJ Fogg: Behavior Model](https://behaviormodel.org/)

## Methodology

- **Searches:** 15 Firecrawl searches and 8 scrapes, from 2026-10-08.
- **Sub-questions:**
  - Krug's core rules
  - Norman's principles and the gulfs
  - the Laws of UX set
  - Tidwell's mobile and behavioural patterns
  - Eyal's model and its ethics
  - finance-app daily loops
  - mobile platform constraints
- **Sources excluded on purpose:** pirated full-text PDFs of the books surfaced in
  search (archive.org, ebook mirrors) were not opened or cited.
- **Confidence:** high for the Laws of UX, Eyal and platform constraints (primary
  sources). Medium for Krug, Norman and Tidwell, where we relied on summaries and notes
  rather than the books, so the principles are well known but the wording is a
  paraphrase of a paraphrase. Medium-low for the finance-app patterns (reviews and one
  company blog).
