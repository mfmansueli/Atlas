# Atlas — project rules

## Design consistency (rule zero)

Design consistency is a development rule in Atlas, not a finishing step. Every screen speaks the same language so the app stays easy to navigate.

### Where the design lives

1. **Source:** canvas *Atlas* → page *Design system* → **README-DS** (rule zero, colour, section icons, type, buttons, badges, shape, AI motion v2), board **64** (every token drawn) and board **68** (motion v2 playing).
2. **In code:** `design-tokens.json` and the `DesignSystem` package (`Tokens.swift`, `Motion.swift`, components, `DesignCatalogView.swift`).
3. **In the app:** debug builds → **Debug → Design System Catalog… (⌥⌘D)**. Check here before and after building or refining a screen.

### Rules for every change

- No raw values in views: no hex colours, font sizes, radii, paddings, durations or springs. Use tokens (`Color.ai`, `.atlasTextStyle(.headline)`, `Radius.card`, `Space.l`, `Motion.base`). If a value is missing, add the token to README-DS, `design-tokens.json` and the module first.
- Colour meaning: **blue** = what you do (one filled blue per card or sheet; repeated actions are tinted); **purple** = what AI brought (never a filled action button; filled only when the assistant waits for you); green/amber/red describe state; AI failures are amber; non-AI loading is a grey skeleton.
- Type: only the ten `AtlasTextStyle`s. Nothing under 10 pt.
- Buttons: only the seven kinds in README-DS §4. Starting AI from inside a page = secondary + sparkles + purple label.
- Motion: only the five AI effects of Motion v2 (`trail`, `working`, `arrived`, `decided`, `needsYou`) through the `DesignSystem` modifiers. At most one loop on screen; no one-shot over 1.2 s; nothing animates on opening a screen; progress only from countable units, never from time; every effect reads Reduce Motion.
- Done means: tokens only; checked in light, dark, Increase Contrast and Reduce Motion, in the screen and in the catalog.
- Changing the system: README-DS and boards first, then tokens and module, then screens.

When a screen in the prototype disagrees with README-DS, build README-DS.

## Voice and content (rule zero for words) — README-DS §9 and §10

Every word must make the next decision faster. Short, clear, and enough to decide with full confidence.

- **One source:** README-DS §9 (voice, three layers, risk levels, templates, words) and §10 (hierarchy). In code: `design-tokens.json → copy` and `Copy.swift`.
- **Every string has a kind.** In the String Catalog, each comment starts with `kind:<kind>` (button, toast, error, banner…). `scripts/copy-lint.py` checks the limits and banned words; it runs in CI and fails the build.
- **Three layers per decision:** title (≤ 8 words, result first) · why (≤ 110 characters, one number) · details on demand. Optional gloss (“Means: …”) and how-sure (Not very sure · Fairly sure · Sure).
- **Safety by risk level, once per screen:** 0 nothing · 1 toast with Undo · 2 one line in Review & Push · 3 confirmation sheet (what, who, when, how to undo) · 4 confirm in place naming what goes.
- **Apple's errors are never shown raw.** Use `AppleErrorCopy` (401, 403, 404, 409, 429, 5xx, offline, expired key, partial). The code and raw message go in Details.
- **Text from the assistant (MCP)** arrives as `AssistantSuggestion` fields. Call `problems()`; if not empty, refuse with the reasons so the assistant rewrites. Never render free text from MCP.
- **Words:** suggestion, push, Review & Push, Autopilot, assistant, capture, set, template. Apple's own terms stay where App Store Connect uses them. Never: simply, just, easily, seamlessly, powerful, leverage, AI-powered, magic, please, oops, successfully, “!”.
- **Hierarchy:** section top = summary line → first card → safety line. Order by impact (blocks App Review → revenue → reach → polish). One banner per screen; at most 6 cards before “Show N More”; group repeats (“12 countries: lower price”). Card order: title · why · (gloss) · actions · details.
- **Done means:** the string passes the lint, fits at 860 × 560 and in German (+30%), and has a VoiceOver label of name, state, count.
- **Snapshot check:** add each screen's empty, loading, error and done states to the snapshot tests, so copy changes are reviewed as images.

### Sidebar footer (approved 24 Nov · README-DS §11, board 71)

- Two fixed rows at every height: **Settings** and **Help ▾** side by side with their names, then the Version card. Never icon-only.
- Help ▾ is a menu: Atlas Help (⌘?), Show the Tour, Keyboard Shortcuts (also in macOS's Help menu).
- Under 600 pt of sidebar height: hide the app card's "other apps" line and tighten rows to 27 pt. Sections never disappear; if they ever don't fit, the list scrolls under the footer with a 14 pt fade.
