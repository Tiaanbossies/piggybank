# Visual rework 01: visual principles digest

Session 1 of the Piggybank visual rework epic, written 2026-10-09. It sits alongside
`docs/ux-rework/01-principles.md`, which covers the behaviour principles (Krug, Norman,
Yablonski, Tidwell, Eyal) and stays the source for them. This digest adds the
**visual and interaction-craft** layer. The audit (`03-visual-audit.md`) and the visual
spec (`04-visual-spec.md`) cite it by ID, for example "R4" or "J6".

**How this was built.** It comes from public sources only:
- the authors' own sites and articles (refactoringui.com, adhamdannaway.com,
  practical-ui.com, atomicdesign.bradfrost.com, bradfrost.com)
- publisher and Google Books pages
- platform guidance (Material Design, Android Developers, Apple HIG)
- NN/g and reputable reviews

Every rule is reworded in our own words, and no book text is reproduced. Secondary
summaries are marked *(summary)*. Pirated PDFs that turned up in search were not opened
or cited.

**Each entry has:**
- **Rule:** the principle in one line, in our words.
- **Finance app:** what it means for a personal-finance mobile app.
- **Piggybank check:** the question the audit and spec ask of every screen.

---

## Wathan & Schoger: *Refactoring UI* (R)

Core idea: good-looking UI comes from tactics applied systematically, not from talent.
Constrain every choice to a small scale, then use those scales to build hierarchy.

| ID | Rule | Finance app | Piggybank check | Source |
|---|---|---|---|---|
| R1 | **Hierarchy is everything.** Decide what's primary, secondary and tertiary, then de-emphasise the rest rather than shouting louder about the main thing. | On a money screen exactly one figure is primary. Labels, dates and categories are supporting cast and should look it. | On each screen, can you name the one primary element, and are secondary and tertiary visibly quieter? | [HowToes (summary)](https://howtoes.blog/2025/07/04/refactoring-ui-complete-book-summary-all-key-ideas/), [Updivision review](https://updivision.com/blog/post/book-review-refactoring-ui-by-adam-wathan-steve-schoger) |
| R2 | **Size isn't the only lever.** Use weight and colour for emphasis, not only bigger type. Bump the weight on the key line and grey out the support. | A balance can stay a sensible size if it's the heaviest weight on screen. "Spent today" can be a lighter tone instead of a smaller size. | Is hierarchy built from weight and tone, or only from font size? | [HowToes (summary)](https://howtoes.blog/2025/07/04/refactoring-ui-complete-book-summary-all-key-ideas/) |
| R3 | **Labels are a last resort.** Format data so it explains itself ("R 642 · today"). Where a label is needed, make it quieter than the value. | Money rows often don't need "Amount:" and "Date:". The format carries the meaning. | Does any label sit at the same weight as its value, or could the value's format replace it? | [HowToes (summary)](https://howtoes.blog/2025/07/04/refactoring-ui-complete-book-summary-all-key-ideas/) |
| R4 | **Start with too much white space, then remove it.** Spacing added only until things stop feeling cramped always ends up too tight. | Finance screens that fill every pixel read as anxious. Generous space around the hero reads as calm and in control. | Was the spacing chosen from the top down, or nudged up from cramped? | [Bookey (summary)](https://www.bookey.app/book/refactoring-ui), [Mohit Khare notes](https://mohitkhare.com/blog/notes-refactoring-ui/) |
| R5 | **Use a constrained spacing and sizing system.** Use a short, non-linear scale (e.g. 4, 8, 12, 16, 24, 32, 48, 64), where neighbouring values are clearly different. | Every padding and gap comes from the scale, so screens built months apart still match. | Does every padding, gap and size in this widget come from the token scale? | [Updivision review](https://updivision.com/blog/post/book-review-refactoring-ui-by-adam-wathan-steve-schoger) |
| R6 | **Space between groups must be bigger than space within them.** Ambiguous spacing makes grouping ambiguous. | The gap between "Recent transactions" and its list must be smaller than the gap above the heading. | Is any between-group gap equal to or smaller than a within-group gap? | [Updivision review](https://updivision.com/blog/post/book-review-refactoring-ui-by-adam-wathan-steve-schoger) |
| R7 | **Use fewer borders.** Separate with a background shift, a shadow or space instead. Borders everywhere make a UI busy. | Stacked outlined cards are the "template" look. Tinted grouping reads as designed. | How many borders are on screen, and could space or a tint do each one's job? | [refactoringui.com](https://refactoringui.com/) |
| R8 | **Colours need shades.** Each hue needs a ramp of roughly 5–9 steps, near-white to near-black. A single hex per role isn't a palette. | One green can't do button, chip background, chart fill, dark-mode text and hero. A ramp gives each its own step. | Does each brand and semantic hue have a full ramp, and does every use pick a step from it? | [explainx.ai Refactoring UI skill (summary)](https://explainx.ai/skills/wondelai/skills/refactoring-ui) |
| R9 | **Greys aren't grey.** Tint neutrals slightly toward the brand's temperature, and use near-black, not pure black. | A finance app with a green brand can tint its greys faintly green or warm. This alone makes it feel authored. | Are the neutrals a deliberate tinted ramp, or stock Material greys? | [explainx.ai (summary)](https://explainx.ai/skills/wondelai/skills/refactoring-ui) |
| R10 | **Design in greyscale first, add colour last.** Colour should reinforce a hierarchy that already works without it. | If Home only reads correctly because of the green hero, the hierarchy is borrowed from colour. | Does the screen still read correctly in greyscale? | [explainx.ai (summary)](https://explainx.ai/skills/wondelai/skills/refactoring-ui) |
| R11 | **Depth comes from light.** Raised surfaces are lighter and cast a shadow; inset ones are darker. Use a small, fixed set of shadow levels. | A three-level model (resting, raised, overlay) tells the eye what's tappable and what floats. | Is every shadow one of the defined elevation levels, and does elevation mean the same thing everywhere? | [Updivision review](https://updivision.com/blog/post/book-review-refactoring-ui-by-adam-wathan-steve-schoger) |
| R12 | **Overlap elements to create layers.** Offsetting one element over another adds depth without decoration. | A hero card that overlaps the header band, or an avatar breaking a card edge, gives a flat stack a third dimension. | Is everything a flat stack of same-plane cards? | [HowToes (summary)](https://howtoes.blog/2025/07/04/refactoring-ui-complete-book-summary-all-key-ideas/) |
| R13 | **Fine details finish a design.** Accent borders, coloured icon backgrounds and custom bullets are the small touches that make it look finished. | Category icons with a colour per category, and a subtle top accent on the hero, cost little and read as care. | Which small touch would make this screen look finished rather than default? | [Updivision review](https://updivision.com/blog/post/book-review-refactoring-ui-by-adam-wathan-steve-schoger) |
| R14 | **Don't let typography default.** Pick a scale (around 12, 14, 16, 18, 20, 24, 30, 36…), keep line height tighter for big text and looser for small text, and tighten letter spacing on large headings. | Money heroes in a big size with tight tracking and tabular figures look precise. Default tracking at 40 sp looks loose. | Is every text style from the scale, with line height and tracking set for its size? | [Updivision review](https://updivision.com/blog/post/book-review-refactoring-ui-by-adam-wathan-steve-schoger) |
| R15 | **Empty states deserve design.** They're the first impression of a feature, so give them an illustration and one clear action. | Empty Goals, Savings and Transactions are where a new user meets the app. | Does each empty state have a picture, one sentence and one action? | [HowToes (summary)](https://howtoes.blog/2025/07/04/refactoring-ui-complete-book-summary-all-key-ideas/) |

## Dannaway: *Practical UI* (P)

Core idea: logic-driven guidelines, not gut feel. Most rules come with a measurable
check: a ratio, a size or a count.

| ID | Rule | Finance app | Piggybank check | Source |
|---|---|---|---|---|
| P1 | **Space by relatedness.** Think of the UI as rectangles nested in rectangles. Use small spacing inside, and grow it outward. | Row → row group → section → screen: each level gets a bigger step. | Does spacing grow with each level of nesting? | [Dannaway: 14 UI design tips](https://www.adhamdannaway.com/blog/ui-design/ui-design-tips-14) |
| P2 | **Use predefined spacing on an 8-point grid** (4-point for fine detail). Make larger steps grow faster, like a type scale. | XS 4 · S 8 · M 16 · L 24 · XL 32 · 2XL 48 · 3XL 64 is a scale anyone can apply without deciding. | Does any value fall outside the 4/8 grid? | [Dannaway: 14 UI design tips](https://www.adhamdannaway.com/blog/ui-design/ui-design-tips-14), [Dannaway: design systems](https://www.adhamdannaway.com/category/blog/design-systems) |
| P3 | **Text contrast is at least 4.5:1.** Large text (18.66 px+ bold or 24 px+ regular) is at least 3:1. | Light text on a green hero is the classic failure. Every hero label has to be measured. | Measured, not eyeballed: does every text/background pair pass? | [Dannaway: 14 UI design tips](https://www.adhamdannaway.com/blog/ui-design/ui-design-tips-14) |
| P4 | **UI elements are at least 3:1** against their background: borders, icons, button fills, progress tracks. | A pale mint progress track or a hairline card border can vanish for low-vision users. | Does each control's shape pass 3:1 against what's behind it? | [Dannaway: 14 UI design tips](https://www.adhamdannaway.com/blog/ui-design/ui-design-tips-14) |
| P5 | **One primary button per view.** Make the most important action the only filled one. | "Add" is the primary on most tabs. Two filled buttons on one screen means neither leads. | How many filled buttons are visible at once? | [Dannaway: 14 UI design tips](https://www.adhamdannaway.com/blog/ui-design/ui-design-tips-14) |
| P6 | **Don't rely on colour alone.** Pair colour with text, an icon or a shape. | Red "over budget" also says "over" in words and shows a full bar. Income in green also carries a "+". | Would the meaning survive for a colour-blind user? | [Dannaway: 14 UI design tips](https://www.adhamdannaway.com/blog/ui-design/ui-design-tips-14) |
| P7 | **Use two weights: regular and bold** (or semibold). Thin and extra-light weights hurt legibility even when the contrast passes. | Two weights of Manrope (400/600 or 400/700) give a clear system. Light weights on money look fragile. | Are more than two weights in play on one screen? | [Dannaway: 14 UI design tips](https://www.adhamdannaway.com/blog/ui-design/ui-design-tips-14) |
| P8 | **Reduce letter spacing on large text.** Big headings look loose at default tracking. | The hero amount and screen titles at large sizes want tighter tracking. | Are display sizes tracked tighter than body sizes? | [Dannaway: 14 UI design tips](https://www.adhamdannaway.com/blog/ui-design/ui-design-tips-14) |
| P9 | **Remove containers where they add nothing.** Not every group needs a card, and space can group on its own. | Fewer cards, more grouping by space and type, so the screen is calmer. | Which cards on this screen could be removed without losing grouping? | [Dannaway: 14 UI design tips](https://www.adhamdannaway.com/blog/ui-design/ui-design-tips-14) |
| P10 | **Minimalism isn't simplicity.** Hiding labels or affordances to look clean can make an app harder to use. | Icon-only app-bar actions look clean but cost recall. | Did anything get *less* clear in the name of looking clean? | [Dannaway: 14 UI design tips](https://www.adhamdannaway.com/blog/ui-design/ui-design-tips-14) |
| P11 | **Avoid pure black text on white**; a very dark grey reads better. In dark mode, avoid pure white on pure black for the same reason. | Our `#111812` ink is already right. Check that the dark theme isn't `#FFF` on `#000`. | Are the extremes softened in both themes? | [Dannaway: UI design archive](https://www.adhamdannaway.com/category/blog/ui-design) |
| P12 | **Balance icon and text pairs.** Icons are visually heavier than text at the same colour, so darken or weight the text to match. | Bottom-nav labels next to filled icons. Category chips. | Does an icon overpower its label anywhere? | [Dannaway: 14 UI design tips](https://www.adhamdannaway.com/blog/ui-design/ui-design-tips-14) |
| P13 | **Dark mode is its own palette, not an inversion.** Plan colour tokens with a light and a dark value for each role. | Each role (surface, ink, accent, on-accent, danger) gets a dark value chosen for contrast, not just flipped. | Does every colour token have a deliberately chosen dark value that passes contrast? | [practical-ui.com](https://www.practical-ui.com/), [Bryan Anthonio takeaways](https://bryananthonio.com/blog/takeaways-practical-ui-book/) |
| P14 | **Use a type scale and limit the spacing options.** Fewer choices mean faster, more consistent decisions. | A fixed type ramp (display, title, body, label, money sizes) replaces ad-hoc `fontSize:` values. | Does any widget set a raw font size or padding instead of a token? | [Bryan Anthonio takeaways](https://bryananthonio.com/blog/takeaways-practical-ui-book/) |

## Cooper et al.: *About Face* (C)

Core idea: design for the user's *goals*, not their tasks. Fit the product's posture to
how it's used, and remove every bit of work that doesn't serve the goal (excise).

| ID | Rule | Finance app | Piggybank check | Source |
|---|---|---|---|---|
| C1 | **Goal-directed design.** People use software to reach end goals ("feel in control of my money"), not to do tasks ("categorise a row"). Design for the goal. | The goal is "know I'm OK this month", not "view budgets". Home's hero answers the goal directly. | Which end goal does this screen serve, and is that goal visible in its first view? | [Dubberly: Cooper and Goal-Directed Design](https://www.dubberly.com/articles/alan-cooper-and-the-goal-directed-design-process.html), [sobrief (summary)](https://sobrief.com/books/about-face-3) |
| C2 | **Personas over "the user".** Design for specific archetypes with specific goals. | Our primary persona is the daily checker: 30-second opens, one hand, wants reassurance. A secondary persona is the monthly planner. | Which persona is this screen for, and does its visual weight match that persona's need? | [Dubberly](https://www.dubberly.com/articles/alan-cooper-and-the-goal-directed-design-process.html) |
| C3 | **Posture: transient vs sovereign.** Transient apps are opened briefly for one job and need bold, legible, glanceable layouts. Sovereign apps are used for long stretches and can be denser. | Piggybank's daily loop is *transient*: big type, strong hierarchy, few elements. Plan and Invest lean *sovereign* and can carry more density. | Is this screen styled for its posture: glanceable (Home, Penny) or dense (Plan, Invest detail)? | [uxdesign.cc: Product posture](https://uxdesign.cc/product-posture-sovereign-vs-transient-vs-daemonic-8ecc1f7e6a18), [Google Books ToC](https://books.google.com/books/about/About_Face.html?id=4c4XBAAAQBAJ) |
| C4 | **Eliminate excise.** Excise is work the tool demands that doesn't move the goal forward: navigating, confirming, waiting, re-entering. | Every confirm dialog, every extra screen to reach "add", every spinner is excise. Motion must never add excise by delaying a task. | What on this screen is work for the app's sake rather than the user's? | [Google Books ToC: "Types of Excise", "Excise Is Contextual"](https://books.google.com/books/about/About_Face.html?id=4c4XBAAAQBAJ) |
| C5 | **Orchestration and flow.** Good products keep people absorbed by being invisible: no interruptions, no modal stops, feedback in place. | Undo instead of confirm, inline saved highlights instead of dialogs, and sheets that don't block the list behind them. | Does anything interrupt the user to report something they didn't ask about? | [Google Books ToC: "Orchestration and Flow"](https://books.google.com/books/about/About_Face.html?id=4c4XBAAAQBAJ) |
| C6 | **Motion, timing and transitions explain change.** Use animation to show where things come from and go to, quickly, and never as a show. | A row growing into its detail tells the user where they are. A 600 ms flourish on every tap is excise. | Does this animation explain a change of place or state, inside the time budget? | [Google Books ToC: "Motion Timing and Transitions"](https://books.google.com/books/about/About_Face.html?id=4c4XBAAAQBAJ) |
| C7 | **Design for intermediates.** Most users are perpetual intermediates: past onboarding, never experts. Optimise for them, with help for beginners and shortcuts for experts. | Don't style screens around the first-run tutorial or the power user. The 3rd-month user is the target. | Is this screen optimised for someone in their third month of use? | [sobrief (summary)](https://sobrief.com/books/about-face-3) |
| C8 | **Digital etiquette: be considerate.** Remember preferences, don't ask twice, take responsibility for errors, and stay quiet when there's nothing to say. | Penny shouldn't celebrate trivia or nag. Errors say what Piggybank will do, not what the user did wrong. | Would a considerate person behave the way this screen does? | [Google Books ToC: "Digital Etiquette"](https://books.google.com/books/about/About_Face.html?id=4c4XBAAAQBAJ) |
| C9 | **Visual design serves behaviour.** Integrate visual design with interaction from the framework stage, not as a skin at the end. | The visual rework designs states (loading, empty, error, success) together with the look, not after it. | Was this component designed with all of its states, or only the happy one? | [Google Books ToC: "Integrating Visual Design"](https://books.google.com/books/about/About_Face.html?id=4c4XBAAAQBAJ) |

## Frost: *Atomic Design* (A)

Core idea: build interfaces as a system of nested parts. The chemistry labels matter less
than the discipline of composing small, reusable pieces into larger ones, and checking
them in real context.

| ID | Rule | Finance app | Piggybank check | Source |
|---|---|---|---|---|
| A1 | **Atoms:** the smallest pieces that can't be broken down further. Colours, type styles, icons, a button, a chip, an amount text. | `MoneyText`, `IconChip`, the percent pill and the primary button are atoms. Tokens sit beneath them. | Is each atom defined once and themed by tokens? | [Atomic Design ch. 2](https://atomicdesign.bradfrost.com/chapter-2/) |
| A2 | **Molecules:** small groups of atoms doing one job together. | A transaction row (icon + title + meta + amount) or a progress bar with its label and amount. | Does each molecule do one thing, and is it reused rather than rebuilt per screen? | [Atomic Design ch. 2](https://atomicdesign.bradfrost.com/chapter-2/), [bradfrost.com](https://bradfrost.com/blog/post/atomic-web-design/) |
| A3 | **Organisms:** distinct sections built from molecules, either varied (a header) or repeated (a list). | The hero, the needs-attention card, the recent-transactions group, the allocation chart card. | Is each section of a screen an organism other screens can use? | [bradfrost.com](https://bradfrost.com/blog/post/atomic-web-design/) |
| A4 | **Templates:** page-level layouts that show content *structure*, not final content. | The tab-root template: app bar, hero slot, sections, FAB clearance, bottom nav. The detail template. The sheet template. | Do all tab roots share one template, so spacing and structure can't drift? | [Atomic Design ch. 2](https://atomicdesign.bradfrost.com/chapter-2/) |
| A5 | **Pages:** templates with real content, used to test the system's resilience against long names, zero values, 30 rows and errors. | Our golden tests are the pages: real-shaped sample data, light and dark, with edge cases. | Has this component been seen with long text, zero, a negative value, empty and error? | [Atomic Design ch. 2](https://atomicdesign.bradfrost.com/chapter-2/) |
| A6 | **The stages aren't a sequence.** Move between abstract and concrete constantly, and let pages feed back into atoms. | Fixing the hero contrast on a page should change the token, not the page. | When a page needs a tweak, is it made in the token or atom, or patched locally? | [Atomic Design ch. 2](https://atomicdesign.bradfrost.com/chapter-2/), [Qt: why the labels don't matter](https://www.qt.io/software-insights/atomic-design-systems-why-the-labels-dont-matter) |
| A7 | **Reuse before create.** A system earns its keep through reuse, and a new one-off widget is a cost. | Map every new visual component to an existing widget in `lib/shared/widgets/` before creating anything. | Did this step create a widget that an existing one could have become? | [cfpb design system](https://cfpb.github.io/consumerfinance.gov/atomic-structure/), [Revolut design principles](https://www.revolut.com/blog/post/our-top-5-design-principles-at-revolut/) |

## Johnson: *Designing with the Mind in Mind* (J)

Core idea: design rules come from how perception, attention and memory actually work.
Know the mechanism, and you know when a rule bends.

| ID | Rule | Finance app | Piggybank check | Source |
|---|---|---|---|---|
| J1 | **Perception is biased by expectation.** People see what they expect, and miss what they don't. | A familiar finance layout (balance on top, a feed below) is read faster than a novel one. An unexpected new element gets missed. | Is anything important placed where users won't be looking for it? | [ACM DL: 2nd ed.](https://dl.acm.org/doi/10.5555/2600170), [UXmatters interview](https://www.uxmatters.com/mt/archives/2012/02/designing-with-the-mind-in-mind-an-interview-with-jeff-johnson.php) |
| J2 | **Gestalt: proximity, similarity, continuity, closure, symmetry, figure/ground, common fate.** The eye groups things automatically, and the design either uses that or fights it. | Rows that animate together read as one group (common fate). Same-styled chips read as one set (similarity). | Do the automatic groupings match the intended ones, including what moves together? | [sobrief (summary)](https://sobrief.com/books/designing-with-the-mind-in-mind), [Elsevier](https://educate.elsevier.com/book/details/9780124079144) |
| J3 | **Structure aids scanning.** People scan structured text far faster than prose: headings, lists, aligned columns. | Right-aligned tabular amounts in a column let the eye compare values without reading. | Are amounts aligned to a column with tabular figures? | [sobrief (summary)](https://sobrief.com/books/designing-with-the-mind-in-mind) |
| J4 | **Colour vision is limited.** It's tuned to contrast more than absolute colour, struggles with pale or small patches, and varies (colour blindness). | A thin red line on a small chart is weak signal. Pale mint pills on white are close to invisible for some. | Do small or pale colour signals carry meaning on their own? | [sobrief (summary)](https://sobrief.com/books/designing-with-the-mind-in-mind) |
| J5 | **Peripheral vision is poor.** Only the centre of gaze is sharp, so changes at the edges get missed unless they move or contrast. | A snackbar at the bottom or a badge on a far tab can go unseen. Motion is what makes a peripheral change noticeable. | Will a change happening away from the user's focus be noticed, and is motion used *only* where noticing matters? | [sobrief (summary)](https://sobrief.com/books/designing-with-the-mind-in-mind) |
| J6 | **Reading is unnatural.** It's learned and effortful, so minimise text, use plain words, and avoid centred or all-caps blocks. | Short labels, sentence case, left-aligned body. | Is there a paragraph where a phrase would do? | [sobrief (summary)](https://sobrief.com/books/designing-with-the-mind-in-mind) |
| J7 | **Attention is narrow and goal-driven.** People notice what serves their current goal and ignore the rest ("banner blindness"). | Decoration competing with the hero gets ignored at best, and slows the glance at worst. | Is anything on the screen competing with the user's current goal for attention? | [sobrief (summary)](https://sobrief.com/books/designing-with-the-mind-in-mind) |
| J8 | **Working memory is tiny** (about 3–5 items for seconds). Don't make people hold numbers across screens. | Show "left to spend" rather than making the user subtract spent from budget. | Does the user need to carry a number from one place to another? | [sobrief (summary)](https://sobrief.com/books/designing-with-the-mind-in-mind) |
| J9 | **Recognition beats recall.** It's easier to spot something than to remember it, which is why labelled icons and visible options win. | Labelled app-bar actions, category icons *with* names. | Is any action icon-only where a label would remove the need to remember? | [UXmatters interview](https://www.uxmatters.com/mt/archives/2012/02/designing-with-the-mind-in-mind-an-interview-with-jeff-johnson.php) |
| J10 | **Respond on human time.** About 0.1 s feels instant (cause and effect); about 1 s keeps the train of thought, so show progress beyond it; about 10 s is the limit for staying on task. Acknowledge input inside the shortest deadline. | A tap must visibly respond within 100 ms (press state, haptic). A load past ~1 s needs a skeleton. Penny's reply past several seconds needs a living indicator. | Does every tap acknowledge within 100 ms, every load past 1 s show structure, and every long wait show progress? | [Johnson, Talks at Google](https://www.youtube.com/watch?v=Rh18iJ8gSfI), [NN/g response time limits](https://www.nngroup.com/articles/response-times-3-important-limits/) |
| J11 | **Learning comes from consistency and real-world mapping.** Consistent patterns become automatic, and inconsistency forces conscious thought. | The same gesture, colour and animation should mean the same thing on every tab. | Does the same visual or motion mean the same thing on every screen? | [Elsevier](https://educate.elsevier.com/book/details/9780124079144) |

## Additions to Krug, Norman and Tidwell (X)

`docs/ux-rework/01-principles.md` already covers these authors for behaviour (K1–K7,
N1–N9, T1–T13). Only **visual and interaction-craft** points missing there are added
here.

| ID | Rule | Finance app | Piggybank check | Source |
|---|---|---|---|---|
| X1 | **Krug: make clickable things obviously clickable.** Visual cues, not hover or guesswork, tell people what responds. (Extends K1/K2.) | Tappable cards need a chevron, elevation or press state. Static cards must not look like buttons. | Can a user tell tappable from static *without tapping*? | [Readingraphics (summary)](https://readingraphics.com/book-summary-dont-make-me-think/) |
| X2 | **Krug: reduce visual noise.** Everything competing equally is noise, so mute the background and kill the clutter. (Extends K2/K5.) | Borders, icon circles and repeated pills on every row add noise. | Which repeated decoration could go from every row? | [Helios Design](https://www.heliosdesign.com/blog/web/insights-from-dont-make-me-think-by-steve-krug.html) |
| X3 | **Norman: feedforward.** Show what will happen *before* the action: a preview, a swipe revealing its result, a disabled state that explains itself. (Extends N1/N3.) | The swipe-to-confirm background shows "Confirm" in colour before release, and the Save button reads "Save R 642,35". | Does the control preview its outcome before commit? | [NN/g: The Two UX Gulfs](https://www.nngroup.com/articles/two-ux-gulfs-evaluation-execution/) |
| X4 | **Norman: emotional design, three levels.** Visceral (looks good immediately), behavioural (works well in use), reflective (the meaning and self-image it gives). (Not covered in 01-principles.) | Visceral: the first glance at Home. Behavioural: tap response and motion. Reflective: "I'm someone who's on top of my money." | Which of the three levels does this screen fail? | [UX Mag on Norman](https://uxmag.medium.com/understanding-don-normans-principles-of-interaction-6dffdb2287b1) |
| X5 | **Tidwell: visual hierarchy patterns.** Use a centre stage, a visual framework shared by every page, and titled sections. (Extends T9–T13.) | One shared tab-root framework, so every tab feels like one product. | Do all five tabs share the same visual framework? | [Tidwell 3rd ed., O'Reilly](https://www.oreilly.com/library/view/designing-interfaces-3rd/9781492051954/) |
| X6 | **Tidwell: data-viz patterns.** Datatips, legends next to the data, and few colours ordered by value. | The allocation donut wants on-palette colours and a direct legend. A trend chart wants a datatip on press. | Is every chart colour from the palette ramp, and labelled where it sits? | [Tidwell 3rd ed., O'Reilly](https://www.oreilly.com/library/view/designing-interfaces-3rd/9781492051954/) |

---

## The twelve visual checks every spec decision must answer

Distilled from the tables above. The audit uses them per screen, and the spec answers
each one per component.

1. **One primary** element per screen, quieter secondaries (R1, R2, J7).
2. **Measured contrast:** text 4.5:1, large text and UI parts 3:1, in both themes (P3, P4, P13).
3. **Tokens only:** spacing, type, radius, elevation and colour come from scales (R5, R14, P2, P14).
4. **Group by space first,** containers only where they earn it (R6, R7, P1, P9).
5. **Palette with ramps** and tinted neutrals; no colour carries meaning alone (R8, R9, P6, J4).
6. **Depth means something:** a fixed elevation model, the same meaning everywhere (R11, R12).
7. **Two weights,** tabular money figures, tracked display sizes (P7, P8, R14, J3).
8. **Tappable looks tappable;** static doesn't (X1, P10, J9).
9. **Respond within 100 ms;** skeleton past 1 s; never delay a task (J10, C4, C6).
10. **Every state designed:** loading, empty, error, success, offline (C9, R15, A5).
11. **Posture-fit density:** glanceable daily screens, denser planning screens (C3).
12. **Reuse before create;** fix the atom, not the page (A6, A7).

## Sources

Author and primary:
- Refactoring UI: https://refactoringui.com/
- Practical UI: https://www.practical-ui.com/ · https://www.adhamdannaway.com/blog/ui-design/ui-design-tips-14 · https://www.adhamdannaway.com/category/blog/design-systems · https://www.adhamdannaway.com/category/blog/ui-design
- Atomic Design: https://atomicdesign.bradfrost.com/chapter-2/ · https://bradfrost.com/blog/post/atomic-web-design/
- About Face, 4th ed.: https://books.google.com/books/about/About_Face.html?id=4c4XBAAAQBAJ (table of contents)
- Designing with the Mind in Mind: https://educate.elsevier.com/book/details/9780124079144 · https://dl.acm.org/doi/10.5555/2600170 · https://www.youtube.com/watch?v=Rh18iJ8gSfI · https://www.uxmatters.com/mt/archives/2012/02/designing-with-the-mind-in-mind-an-interview-with-jeff-johnson.php
- Designing Interfaces, 3rd ed.: https://www.oreilly.com/library/view/designing-interfaces-3rd/9781492051954/
- NN/g response time limits: https://www.nngroup.com/articles/response-times-3-important-limits/ · NN/g Two UX Gulfs: https://www.nngroup.com/articles/two-ux-gulfs-evaluation-execution/

Summaries and reviews *(summary)*:
- https://howtoes.blog/2025/07/04/refactoring-ui-complete-book-summary-all-key-ideas/
- https://updivision.com/blog/post/book-review-refactoring-ui-by-adam-wathan-steve-schoger
- https://www.bookey.app/book/refactoring-ui
- https://mohitkhare.com/blog/notes-refactoring-ui/
- https://explainx.ai/skills/wondelai/skills/refactoring-ui
- https://bryananthonio.com/blog/takeaways-practical-ui-book/
- https://www.dubberly.com/articles/alan-cooper-and-the-goal-directed-design-process.html
- https://uxdesign.cc/product-posture-sovereign-vs-transient-vs-daemonic-8ecc1f7e6a18
- https://sobrief.com/books/about-face-3
- https://sobrief.com/books/designing-with-the-mind-in-mind
- https://www.qt.io/software-insights/atomic-design-systems-why-the-labels-dont-matter
- https://cfpb.github.io/consumerfinance.gov/atomic-structure/
- Plus Krug/Norman summaries already cited in `docs/ux-rework/01-principles.md`.

## Methodology

- **Searches:** Firecrawl search (web) per author, preferring author-owned and
  publisher pages. Results from pirated-PDF and document-sharing hosts were discarded
  unopened. Every row was paraphrased from the cited page.
- **Mapping:** rows that only restate `01-principles.md` were dropped; X1–X6 are the
  only Krug/Norman/Tidwell additions.
- **Limits:** About Face rows on excise, flow, motion and etiquette are cited to the 4th
  edition's public table of contents plus summaries, because no fuller author-hosted
  text was used. They are framed as the concepts those chapters name, in our own words.
