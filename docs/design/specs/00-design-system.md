ATLAS · DESIGN SYSTEM · REVIEW AND HANDOFF · 22 NOVEMBER 2026

# The design system, and what the prototype gets wrong

A complete review of the clickable app and the other prototypes: colour, section icons, type, buttons, badges, shape, depth and motion. For each, the rule to build, the SwiftUI to build it with, and every place where the prototype breaks the rule.

**For Claude Code: this README and the board beside it win over the prototype.** The prototype was built screen by screen over several weeks and drifted. When a screen disagrees with a rule here, build the rule. Every disagreement found is listed in “What to fix”, with where it is.

**Applied to the current design, 23 November.** Everything in “What to fix” is in the clickable app (with the Settings, Help and screenshot components it uses), the Welcome and menu bar prototype, the toolbar prototype and the Analytics prototype. All eight AI effects in section 7 play in the clickable app.  
**Fixed on 23 November, after the first pass:** the Screenshots component’s styles applied to the whole app on any screen that shows a screenshot, and they loaded last. So on those screens footnotes stayed 10 pt and tertiary grey, chips kept their old size and radios were drawn at 14 pt. Settings did the same to the section icons while it was open. Both now only style their own boards (last row of “What to fix”).  
**Kept as they were, on purpose:** pages *Estados* and *Documentação e componentes*, which hold boards 1–28, the component sheets and “Foundations”. They show the earlier design and are kept as history. Where they disagree with this README, this README wins.  
**Checked:** all 71 scenes of the clickable app against the previous version: no text newly cut off and no script errors. The Settings, Welcome, toolbar, Help and screenshot boards were compared before and after. Every Accept and Send Reply was clicked.

**On the canvas** (page *Design system*): board **64 · Design system** shows every token, the section icons before and after, the type scale, the seven buttons in light and dark, badges and pills, shape and depth, eight AI effects playing, and do / don’t pairs.

## How the review was done

- Read every colour token, button class and icon colour in the six prototypes: the clickable app (Redesign), Settings, Welcome, Help, the toolbar prototype and Analytics.
- Opened nine screens of the clickable app in light and dark and measured what the browser actually drew: every text size, every button height, every filled button.
- Computed WCAG contrast for every text colour on its background, and the hue distance between the section colours.
- All six prototypes share the same colour values, so the system already has one source; the toolbar and Analytics prototypes only lack the high-contrast set.

## The idea in one paragraph

Atlas is a calm, native Mac tool with one extra voice: the assistant. So the interface has **two colours that mean something** and keeps everything else quiet. **Blue** is what you do (the one main action, selection, what you changed). **Purple** is what AI brings (suggestions, their counts, the assistant at work). Green, amber and red only describe state. The section colours exist to help people find places, never to mean anything. And **motion belongs only to the assistant**: when it works, arrives, writes or is accepted, something moves, gently and once; the rest of the app is still. That restraint is what makes the AI moments feel special.

## What to fix

Ordered by how much each one costs the experience. 1 breaks meaning or accessibility · 2 makes the app feel less finished · 3 cleanup for the build.

|  | Problem | Where, and evidence | Fix |
| --- | --- | --- | --- |
| 1 | **Accept All is blue on some pages and purple on others** ✓ Applied | Blue (`btn pri accb`) in Store Page, Screenshots, App Information; purple (`btn accb mtb`) in In-App Events and Product Pages. Same action, two meanings. | Always the primary blue button; its count badge is the purple part. Purple says “these came from AI”; blue says “do it”. |
| 1 | **Buttons that start AI work are filled purple inside pages** ✓ Applied | “Make the Artwork…” (In-App Events) and “Suggest Pages…” (Product Pages) use `accb mtb`. | Secondary button with the sparkles glyph and purple label (the same look as the Autopilot button at rest). A purple fill is kept for one thing only: the assistant is waiting for you. |
| 1 | **Tertiary gray used for text people must read** ✓ Applied | `--label-3` (#9A9AA0) is 2.8:1 on white, 2.8:1 on dark raised surfaces. Used for about 40 pieces of readable text: sentences such as “Checked again whenever Lumen’s category…”, “No details provided”, “How sure: …”, chart axis labels, the paywall’s Terms and Privacy links, and the field hints on the Connect screen. | Readable text uses `--label-2` (5.3:1). `--label-3` only for placeholders, disabled controls and separators. |
| 1 | **Text smaller than macOS allows** ✓ Applied | Measured in the working UI: 7.5 pt (language monograms, 46 times), 9 and 9.5 pt (deltas, counts) and 10 pt for whole lines (“Northpier Studio · Admin”, version status: 173 times). | Nothing under 10 pt; 10 pt only for counters and timestamps; lines of text start at 11 pt. Language monograms become 10 pt or the flag emoji. |
| 1 | **Section icons collide** ✓ Applied | Screenshots #F08A1C and Reviews #F5A30A are 8° of hue apart; Overview #636366 and App Information #7D7D86 are both gray; In-App Events #E5484D is the error red’s family. | New palette below: Screenshots red-orange, Reviews yellow, In-App Events pink, Overview graphite. Nine colours, at least 23° apart where they sit near each other. |
| 1 | **Atlas Pro is purple** ✓ Applied | The PRO chip, the Upgrade button and the paywall’s left panel use an indigo-to-purple gradient (#4B3BD6 → #8A3CD6). Next to suggestions, “Pro” reads as “AI”. | Pro takes the brand blue gradient. Pro is Atlas; purple stays AI. |
| 2 | **Too many filled blue buttons on one screen** ✓ Applied | Pricing: Accept All 3, two Accept and the selected country are all filled blue. Reviews: every review card has a filled Send Reply (two or three on screen), plus the selected filter. | One filled blue per card or sheet. Repeated row actions (Accept, Send Reply) use the tinted style. Selected filters and segments use the segmented control, not a blue button. |
| 2 | **15 text sizes in the working UI** ✓ Applied | 9, 9.5, 10, 10.5, 11, 11.5, 12, 12.5, 13, 14, 15, 17, 18, 34, plus 7.5. Half-points (10.5, 11.5, 12.5) are 137 pieces of text. | The ten macOS text styles below. Half-points round to the style they were meant to be. |
| 2 | **Odd control heights** ✓ Applied | Besides 24 / 28 / 32: segmented options at 20 (None / Infrequent / Frequent on Age Rating, 31 on one screen), language chips at 26 (In-App Events), country chips at 22 (Pricing), topic chips at 16 (Product Pages). | Segmented 24 (20 when small); every chip 24; icon-only buttons drawn at 16 with a 24 pt hit area. |
| 2 | **21 corner radii and 78 different shadows** ✓ Applied | Radii 1, 2, 3, 4, 5, 6, 6.5, 7, 7.5, 8, 9 … 22. | Seven radii (4, 6, 8, 10, 12, 16, 20) plus capsule; four depth levels: flat, card, popover, sheet. |
| 2 | **Settings uses two purples as tiles** ✓ Applied | AI Assistants #8A3CD6 and Suggestions #BF5AF2 sit side by side in the Settings sidebar. | AI Assistants keeps the AI purple (it is the AI). Suggestions takes indigo #6866E0. |
| 3 | **Colour tokens copied in six files** ✓ Applied | Identical values, two class names (`.alx-l`, `.ax-l`); the toolbar and Analytics copies have no high-contrast set. | One asset catalogue in the app: every colour a named Color Set with Any, Dark and High Contrast variants. (In the prototypes, all six now carry the same values.) |
| 3 | **An unused colour** ✓ Applied | `--dec` is defined and used twice. | Dropped, with the unused pill that used it. |
| 1 | **One component’s styles overrode the app’s** ✓ Applied 23 Nov | The Screenshots component (used for every screenshot image) defined `.t-f`, `.l3`, `.chip`, `.who b`, `.flag`, `.rdo` and the colour tokens again, with the old values, and loaded after the app. Settings did the same for the section icons. So several fixes above never showed on Overview, Store Page or Screenshots. | Each component styles only its own root (the screenshot styles now sit under `.shx`), and shared rules carry the same values everywhere. In the app: one stylesheet of tokens and styles; views never redefine a shared style. |

## 1 · Colour

Every colour has a job and a “never”. Values are the prototype’s; they all pass where they are used, except tertiary text.

| Token | Light | Dark | High contrast (L / D) | Job |
| --- | --- | --- | --- | --- |
| `label` | #1D1D1F | #F2F2F5 | system | Text. Use `.primary`. |
| `label2` | #6B6B70 · 5.3:1 | #A3A3AA · 7.2:1 | system | Secondary text. Use `.secondary`. |
| `label3` | #9A9AA0 · 2.8:1 | #6E6E75 · 3.6:1 | system | Placeholders, disabled, separators. **Never readable text.** Use `.tertiary`. |
| `accent` | #0071E3 | #0A72E8 | #0040DD / #0A64D6 | The primary button, selection, focus, switches, “changed, not pushed”. White on it: 4.7 / 4.6:1. Set as the app’s AccentColor. |
| `accentText` | #0066CC · 5.6:1 | #4DA3FF · 6.9:1 | – | Links and plain buttons. |
| `ai` (mt) | #7A35B0 · 7.1:1 | #D4A3FF · 9.0:1 | – | Text that came from an assistant or Atlas’s checks and waits for you; the sparkles glyph. |
| `aiFill` (mtb) | #8A3CD6 | #B98CFF | #5C1E91 / #E6C8FF | Suggestion count badges, the Autopilot button when the assistant waits for you, AI motion. Label on it: white 5.7:1 / dark #1B0A2E 7.3:1. **Never a section tile, never a filled action button.** |
| `aiSurface` (mt-tint, mt-edge) | rgba(150,70,210,.08), edge .22 | rgba(200,140,255,.10) | – | Suggestion cards and inline suggestions. |
| `ok` | #1D7A3A · 4.8:1 on tint | #5FD38A | – | Live, Accepted, Connected, a check that passes. |
| `warn` | #7A5600 · 6.0:1 on tint | #FFD34D | – | Needs an answer; close to a limit. |
| `err` | #C8102E · 5.9:1 | #FF7A70 | – | Errors, rejected, destructive button text. Never decoration. |
| `brand` | #1FC2FF → #0A5CF2 | | – | The app icon, the Welcome header, About, and Atlas Pro (the PRO chip, Upgrade, the paywall). Nowhere else. |

Surfaces (window #EFEFF2 / #1E1E21, content #FFFFFF / #161618, raised #FFFFFF / #2A2A2E, sidebar, glass) come from the system in the app: `NavigationSplitView`, toolbar and sheets draw their own materials. Don’t paint them.

## 2 · Section icons

Rounded-square tiles with a white SF Symbol, the way System Settings does it. A soft vertical gradient (top lighter) gives them the same finish as macOS’s own. Purple is never used: it means AI.

| Section | Colour (top → bottom) | SF Symbol | Change |
| --- | --- | --- | --- |
| Overview | #4A4A50 → #2C2C30 graphite | `square.grid.2x2.fill` | Darker, so it no longer matches App Information. |
| Store Page | #3D86F7 → #2869D2 blue | `doc.text.fill` | – |
| Screenshots | #F57A35 → #CE5619 red-orange | `iphone` | Moved toward red, away from Reviews. |
| Product Pages | #16A9B6 → #0C848F teal | `doc.on.doc.fill` | – |
| In-App Events | #EC5B8D → #C03B69 pink | `calendar` | Pink instead of the error red. |
| App Information | #8E8E96 → #6B6B73 gray | `info.circle.fill` | The neutral one. |
| Pricing | #3BB466 → #288F4D green | `tag.fill` | – |
| Reviews | #F7BE1A → #D99700 yellow | `star.fill` | Yellow, clearly apart from Screenshots. |
| Analytics | #6866E0 → #4B49B8 indigo | `chart.bar.fill` | – |

- Size: 22 pt tiles in the sidebar (radius 6), 30 pt in Overview rows (radius 8), symbol at 58% of the tile, weight medium.
- The tile is decoration: the label always sits beside it, so the white symbol on yellow (2.6:1) is acceptable, as it is in System Settings.
- Badges beside them: purple counts suggestions; gray counts anything else (Analytics findings).
- Settings panes follow the same palette: General gray, Accounts blue, AI Assistants the AI purple (the one purple tile, because it is the AI), Suggestions indigo, Pricing green, Screenshots red-orange, Notifications red (system convention), Atlas Pro brand gradient, Privacy graphite.
- SF Symbol names are from memory; check each in the SF Symbols app.

## 3 · Type

The macOS text styles, so the app follows the system’s sizes and accessibility settings. Sizes are macOS’s defaults as far as I know; check them against Apple’s typography table before building.

| Style | Size / line | Weight | SwiftUI | Use |
| --- | --- | --- | --- | --- |
| Display | 32 / 38 | Bold | `.system(size: 32, weight: .bold)` | Welcome title only. |
| Large Title | 26 / 32 | Bold | `.largeTitle.bold()` | Onboarding and empty states. |
| Title 1 | 22 / 28 | Semibold | `.title.weight(.semibold)` | Big numbers. |
| Title 2 | 17 / 22 | Semibold | `.title2.weight(.semibold)` | Sheet and Settings pane titles. |
| Title 3 | 15 / 20 | Semibold | `.title3.weight(.semibold)` | Card titles; section titles inside a page. |
| Headline | 13 / 16 | Semibold | `.body.weight(.semibold)` | Row titles, field labels. |
| Body | 13 / 18 | Regular | `.body` | Everything else, fields, buttons. |
| Callout | 12 / 16 | Regular | `.callout` | Descriptions under titles, helper text. |
| Subheadline | 11 / 14 | Regular; Semibold in pills | `.subheadline` | Metadata, pills, badges, column headers. |
| Footnote | 10 / 13 | Regular | `.footnote` | Counters and timestamps only. |

- Monospaced only for IDs, keys and code: `.monospaced()`. Numbers that change (counts, prices, progress) use `.monospacedDigit()`.
- One weight jump per level. Never bold and semibold next to each other in the same line.
- Titles 17 pt and up get −1.5% tracking, as the system does.

## 4 · Buttons

Seven kinds. The rule people will feel: **one filled blue button per card or sheet**, so the eye always knows the next step.

| Kind | Look | Height | Where | SwiftUI (check on macOS 26) |
| --- | --- | --- | --- | --- |
| Hero | Liquid Glass, deep blue tint | 38 | Welcome Get Started, the paywall’s buy button. One per screen. | `.buttonStyle(.glassProminent)` · `.controlSize(.extraLarge)` · `.tint(Color("HeroBlue"))` (#0B63D6) |
| Toolbar | Glass capsule | 32 | Autopilot, Review & Push, Up to Date. | Toolbar items; the system gives them glass. Review & Push with pending changes: `.buttonStyle(.glassProminent)`. |
| Primary | Filled blue, white label | 28 | The one main action of a card or sheet: Submit for Review…, Accept All Languages, Connect. | `.borderedProminent` · `.controlSize(.large)` · `.keyboardShortcut(.defaultAction)` in sheets |
| Secondary | Neutral capsule | 28 | Everything else: Review, Choose Folder…, Cancel. | `.bordered` · `.controlSize(.large)` |
| Row action | Tinted blue (Accept, Send Reply); neutral for the rest | 24 | Actions repeated in a list or inside a suggestion. | `.bordered` · `.tint(.accentColor)` · `.controlSize(.regular)` |
| Plain | Blue text | – | Show Me How, What to Try, links inside text. | `.buttonStyle(.link)` or `.borderless` |
| Destructive | Secondary with red label | 28 / 24 | Delete…, Disconnect…, Remove…. | `Button(role: .destructive)`; confirm in place |

- **Starting AI from inside a page** (Make the Artwork…, Suggest Pages…, an empty slot): secondary button with the `sparkles` symbol and purple label. Never filled.
- **AI waiting for you**: the Autopilot button fills with aiFill and says what it needs (“Choose the Look”). This is the only purple fill.
- **Accept All**: primary blue with a purple count badge. Same in every section.
- Labels are verbs in title case; “…” when the button opens something that asks more. Buttons never wrap.
- Selected filters and segments are segmented controls (`Picker(...).pickerStyle(.segmented)`), not blue buttons.
- If `.controlSize(.large)` on macOS 26 is not 28 pt, keep the system’s sizes and the ladder (hero > toolbar > primary = secondary > row) rather than forcing pixels.

## 5 · Badges, pills, sources

- **Badge** = a count. Capsule 17 pt high, 11 pt semibold, tabular digits. Purple when it counts suggestions waiting for you, gray otherwise. Gone at zero. VoiceOver reads it in the label (“Store Page, 32 suggestions to review”).
- **Pill** = a state. 20 pt, 11 pt semibold, tinted background with its own text colour: Live (ok), Not pushed (accent, with a dot), Suggested (ai, with edge), Needs an answer (warn), Rejected (err), and neutral states (gray).
- **Source chip** = who made it: Claude Code, Built-in, AI provider, Claude Design. Neutral outline with a monogram; never coloured, so it doesn’t compete with the suggestion itself.

## 6 · Shape and depth

- Radii: 4 tags · 6 menu rows, small tiles · 8 fields, sidebar rows · 10 banners, suggestions · 12 cards · 16 popovers, tips · 20 sheets · capsule for buttons, pills, badges, segmented controls. Use `.rect(cornerRadius:, style: .continuous)`.
- Depth: flat (content) · card (0.5 pt line + 3 pt soft shadow) · popover and menu (system) · sheet (system, with scrim). Cards are the only depth the app draws itself.
- Spacing on a 4 pt grid: 4, 8, 12, 16, 20, 24, 32. Page padding 20; card padding 16; between cards 16.

## 7 · AI motion

Professional motion is rare, short and earned. These eight are the whole list, and all eight now play in the clickable app (try them: Accept a suggestion; run Autopilot from the toolbar; connect an assistant in Settings → AI Assistants, then close Settings).

| Effect | When it plays | Spec | SwiftUI | Reduce Motion |
| --- | --- | --- | --- | --- |
| **1 · Working light** (exists, approved) | While an assistant works for this section. | Purple light runs round the Autopilot button, 2.2 s linear loop; sparkles breathe 1.5 s; 2 pt progress bar. | Angular gradient stroke with `.phaseAnimator`; `Image(systemName: "sparkles").symbolEffect(.breathe)` | Still light at the front; bar only. |
| **2 · Arrival** | A suggestion arrives in the part of the page you are looking at. | Tint fades in 0.4 s; one light pass round its edge, 1.1 s ease-out, once. | `.transition(.opacity)` + a trimmed stroke animated once | Tint only. |
| **3 · Text arriving** | Streamed suggestion text, the assistant’s first hello. | Word by word: 0.28 s each, 35 ms apart, from 2 px blur and 2 px lower. | A `TextRenderer` that animates each run | Whole text fades in 0.2 s. |
| **4 · Count tick** | A badge goes up because new suggestions came. | Scale 1 → 1.18 → 1, spring 0.45 s. Going down: no motion. | `.contentTransition(.numericText())` + `.symbolEffect(.bounce)`-like spring on scale | Number changes, no scale. |
| **5 · Accept settles** | You accept a suggestion. | Purple tint goes 0.25 s; a check draws 0.3 s; the card’s height springs closed 0.35 s. | `withAnimation(.spring(duration: 0.35))`; check with `.symbolEffect(.drawOn)` if available, else a trimmed path | Cross-fade 0.15 s. |
| **6 · First-time glint** | Once, 0.8 s after an assistant first connects, so people find the Autopilot button. | One soft purple sheen across the button, 1.2 s. Never again on this Mac. | Masked gradient offset animated once; `@AppStorage` flag | None. |
| **7 · Assistant is typing** | The connection hello, a reply being drafted. | Three dots in a purple-tinted bubble, 1.2 s loop; bubble scales .96 → 1 in 0.25 s. | `Image(systemName: "ellipsis").symbolEffect(.variableColor.iterative)` | Static “…”. |
| **8 · Hero glass** (exists) | Get Started, the paywall’s buy button. | System Liquid Glass; swells under the pointer, squeezes on click. | `.buttonStyle(.glassProminent)` | System handles it. |

### Rules

- Only one looping effect on screen at a time, and only while work is actually running.
- Nothing animates on page load or when switching sections. Motion means “something just happened”.
- Purple light for AI; blue never animates.
- Springs, not bounces: response about 0.35 s, damping about 0.8 for layout; 0.6 only for the count tick.
- Every effect reads `@Environment(\.accessibilityReduceMotion)`; translucency effects read `accessibilityReduceTransparency`.
- Pair the end of real work with sound or haptics only when the window isn’t in front (a notification), never inside the window.

### In the prototype

- **2, 3, 4** play together when an Autopilot run finishes: the visible suggestion cards fade their tint in with one light pass round the edge, their suggested text comes in from a light blur, and the section’s badge in the sidebar swells once. Scene `ap-arrive`.
- **5** on every Accept of an assistant’s suggestion: Store Page, App Information, Pricing, Retention, Screenshot captions, Product Pages (new pages and their captions), In-App Events and What’s New in the submit sheet. Also on Send Reply in Reviews. The card goes neutral, a check replaces the button label, and the card fades before the toast. Undo still works.
- **7 then 3** in the connect sheet: “is writing” dots for 1.5 s, then the hello arrives sentence by sentence (the app does it word by word). Settings scenes `set-wiz-typing`, `set-wiz-hello`.
- **6** once, 0.8 s after Settings closes following the first connection; never again in that session. Scene `ap-glint`.
- With Reduce Motion, each falls back as the table says; Accept skips the delay.

### Where each one appears

- **Store Page, Screenshots captions, App Information:** 1 while suggesting; 3 and 2 as each suggestion lands; 4 on the sidebar badge; 5 on Accept.
- **Reviews:** 1 while drafting replies; 3 for the drafted reply; 5 on Send Reply (the card moves to Replied).
- **Connect an assistant (Settings):** 7 then 3 for the hello; 6 on the Autopilot button after the sheet closes.
- **In-App Events artwork, Screenshots made by Autopilot:** 1 while making; each new image fades in (2 without the edge pass).
- **Welcome and paywall:** 8 only.

## 8 · Accessibility checklist

- All readable text ≥ 4.5:1 (checked above); controls and focus rings ≥ 3:1.
- Colour never alone: suggestions also have the “Suggested” pill and source chip; not pushed has the dot and the word.
- Increase Contrast: the high-contrast accent and AI colours above; card lines go from 0.5 to 1 pt.
- Full keyboard: Return is the primary button in sheets; ⌘K apps; ⌘, Settings; ⇧⌘P Review & Push.
- VoiceOver: badges and pills are part of the element’s label; motion is never the only signal that work finished (the toast and the button label change too).

## For Claude Code: building it

- An asset catalogue with Color Sets named as the tokens above (Any, Dark, and High Contrast for accent and aiFill), and `AccentColor` = accent.
- A small `DesignSystem` module: `Color` extensions for the tokens, `SectionStyle` (colour pair + SF Symbol per section), `Badge`, `Pill`, `SourceChip`, `SuggestionCard`, and view modifiers for effects 2–7 (each reading Reduce Motion itself).
- Use system controls everywhere a system control exists; draw only cards, badges, pills, suggestion cards and the effects.
- Build the screens from this README; use the prototype for layout and content, not for sizes and colours.
- **Check before building:** SF Symbol names, macOS 26 control heights and the Liquid Glass and symbol-effect API names are written from memory.

**Still to check in the real app:** SF Symbol names, macOS 26 control heights, and the Liquid Glass and symbol-effect API names, all written from memory. The App Store and event-card mockups inside the prototype keep Apple’s own sizes on purpose: they copy Apple’s pages, not Atlas’s UI.
