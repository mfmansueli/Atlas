# Design gaps: canvas vs app (audit 2026-11-24)

Read-only audit of the Atlas canvas (https://claude.ai/artifact/6Qcinn3c48pd9oXXMnXWYy: 72 numbered boards, 18 pages,
READMEs Built/Manual/DS/Featuring/An2/Assist, Redesign.dc.html's 264 scenes) against the code (grep, DEBUG scenes in
`Atlas/Debug`, components). Almost all of the canvas is built. Board 69 (assistant chat) was being built at the time
and is not listed.

It looked for screens and states **missing** from the app. It did not compare built screens with their boards by eye.

Use: pick an item, read its board and README section on the canvas, verify the evidence (the code may have moved),
build it with tests (CLAUDE.md rules), and tick it off here.

## Status (24 Nov, evening)

Every item below was built by worktree agents and merged into main (05fbca09, 4e596602, d1d3effb, 0ca0800f, 0936ec18,
2f745543, 06a4623d, 1fb8929a). Tests were written but **not run** yet (unit and UI). Left over:
- App Previews chosen by hand don't open in the Review & Push viewer yet (their row shows the text summary).
- Recommended prices aren't Pro-gated over MCP (no MCP tool checks Pro today).
- `scripts/copy-lint.py` isn't in the repo, so new strings weren't copy-linted; new strings' `kind:` comments reach
  `Localizable.xcstrings` on the next Xcode sync.
- Pro products still don't exist in App Store Connect.

Also fixed the same day: Nominations didn't load ("'actorType' is not a valid field name"): Atlas no longer sends
`fields[actors]` and reads once more without field lists when Apple refuses a parameter (05fbca09).

## Not built

### 1. Board 72 · Icons: only Apple SF Symbols (approved 24 Nov, option B; README-DS §13). Confidence: high
https://claude.ai/artifact/6Qcinn3c48pd9oXXMnXWYy#artboard-States-SF72

- [x] Drop the coloured gradient tiles: `Atlas/Screens/Main/Sidebar/Sections/SectionIconTile.swift` (`section.tileGradient`
      in a `RoundedRectangle`), used by `SidebarSectionRow.swift`, `SectionMenuButton.swift`,
      `Overview/Components/List/OverviewListRow.swift`; Settings panes in
      `Atlas/Screens/Settings/Shell/Tile/SettingsPaneTile.swift` (`pane.tileGradient`).
- [x] Symbols and colours as on the board: `AppWorkspaceSection.systemImage` uses `.fill` variants and `doc.on.doc.fill`
      for Product Pages (board: `rectangle.stack`). There's no system colour per section (`systemBrown` appears nowhere);
      no `SectionStyle` / `StatusSymbol`.
- [x] No text characters as icons (§13 forbids them): about 24 places, e.g. `GuidedReviewStepView.swift:99` ("✓ "),
      `GuidedChecksCard.swift:156` ("✓"), `AutopilotMomentRow.swift:45` ("▶ Play").
- [x] Not checked: the symbol column in menus.
- Where the canvas (after the 24 Nov SF Symbols pass, canvas v48) and the code differ:
  - Sidebar: outline `square.grid.2x2`, `doc.text`, `info.circle`, `tag`, `star`, `chart.bar` vs `.fill` in Swift.
    Product Pages: `rectangle.stack` vs `doc.on.doc.fill`.
  - Settings panes (canvas → Swift): General `gearshape` → `gearshape.fill`; Accounts `key` → `key.horizontal.fill`;
    Suggestions `tag` → `text.badge.checkmark`; Pricing `dollarsign.circle` → `tag.fill`; Notifications `bell` →
    `bell.badge.fill`; Atlas Pro `star` → `star.fill`; Privacy & Data `hand.raised` → `hand.raised.fill`.
  - "Open App Store Connect": `arrow.up.right.square` vs `arrow.up.forward.square` (`ConnectHelpSteps`).
  - Help "Show Me": `arrow.up.right.square` vs `arrow.up.forward.app` (`HelpShownBanner`).
  - Autopilot: `sparkles`/`sparkle` vs `wand.and.stars` (`ProFeature.autopilot`).
  - On the canvas, absent from Swift: `flag`, `macwindow`, `lifepreserver`, `keyboard` (Help),
    `wrench.and.screwdriver`, `power` (menu bar Quit), `paintpalette`, `star.bubble`, `apps.iphone`,
    `macbook.and.iphone`, `shield`, `square.and.pencil`, `bolt`, `plus.app`, `archivebox`, `equal`.

## Partly built

### 2. Paywall: Free plan limits (page "Proposta · Novo design", "Paywall · every state", README-Monetization). Confidence: medium-high
https://claude.ai/artifact/6Qcinn3c48pd9oXXMnXWYy#artboard-States-Paywall

- Built: the paywall, the purchase, and the locks on Accept All, Autopilot, suggested prices, Retention, event art and
  a second app.
- [x] The 3-template and device limit: `Entitlements.freeTemplateLimit = 3` is never read; there's no
      `pro.require(.template)`, and `PaywallContext.template` is unused.
- [x] Block a second App Store Connect account: `.secondApp` is only checked when switching apps
      (`MainView.swift:182`), not in `AddKeySheet` / `AccountsSheet`.
- README-Built §4 also lists this as not done, and notes the Pro products don't exist in App Store Connect yet.

### 3. In-App Events at the 860 × 560 minimum window (boards 40 and 47: scenes `ev-s`, `ev-event-s`, `ev-view-s`, `ea-brief-s`). Confidence: medium
https://claude.ai/artifact/6Qcinn3c48pd9oXXMnXWYy#artboard-States-Rv40 ·
https://claude.ai/artifact/6Qcinn3c48pd9oXXMnXWYy#artboard-States-Rv47

- Only the event page's top stacks below 700 pt (`InAppEventPage.swift:31`).
- [x] The four small-window states: none has a DEBUG scene, while every other `ev-*` scene has one. README-Built §2 and
      §4 say they weren't done.

### 4. Recommended prices when creating a subscription (board 18, page "Estados · design anterior"; README-Assist §5). Confidence: medium
https://claude.ai/artifact/6Qcinn3c48pd9oXXMnXWYy#artboard-States-Assist-Pricing

- [x] The choice between a recommended price, Apple's prices now with a review later, or equalized prices, and the
      112-territory review sheet. `Atlas/Screens/Pricing/NewSubscription/NewSubscriptionSheet.swift` has none of it.
- The board is on an old page, but README-Built §4 (22 Nov) still lists "Recommended prices" as pending: confirm it's
  still wanted.

### 5. In-App Events requests to the assistant through the toolbar (board 40 scene `ask-ev`, board 56). Confidence: low-medium
https://claude.ai/artifact/6Qcinn3c48pd9oXXMnXWYy#artboard-States-Rv56

- Product Pages already goes through `AssistantAskCenter` (`ProductPagesSectionView.swift:259`).
- [x] Events' "Ask Claude Code…" buttons for art and the deep link call `launcher.start` directly
      (`InAppEventsSectionView.swift:380-381`), not through the AskCenter. The general events request exists only in the
      toolbar's Autopilot menu (`WorkspaceAutopilotAsk.swift`).

### 6. Review & Push viewer (board 25, previous design). Small gap, confidence: low
https://claude.ai/artifact/6Qcinn3c48pd9oXXMnXWYy#artboard-States-ReviewViewer

- [x] The App Preview plays without sound.
- [x] No "Live Now | New" comparison in the progress ("Live now" exists only in `StudioPreviewBuilder`). README-Built lists
      both as gaps.

## Gaps in the READMEs with no board yet

- [x] App Preview by hand in Screenshots (upload, replace or delete a video): README-Manual marks it "next". There's no
      code: `Screenshots/Hand` and `Screenshots/LanguagePage` don't handle video. Only Product Pages has
      "Choose App Previews…".
- [x] A "?" button next to the section title, and errors linking to "Fix a problem": README-Settings says "Not drawn
      yet"; no code.

## Probably superseded (not counted as missing)

- Pages "Estados · design anterior" and "Documentação · design anterior" (boards 2–28): replaced by the redesign.
- `ov-tabs` ("Before: tabs in the toolbar"): history.
- README-DS §7's "first-time glint": Motion v2 keeps only five effects.
- Nominations' olive colour in §1: §13 changed it to systemBrown.
- Board 54's `cp-push` states: a page-only Review & Push was a decision recorded in README-Built.
- Settings rows left out of board 48: also a recorded decision.
- "▶ App clicável", "Mapa do app", "App real": prototypes or captures of the existing app.

## Checked as built

41–55 (52 included), 56 (Product Pages), 57, 58, 59–62 (`an-*` plus billing grace and pausing the phased release), 63
(tour), 64 and 68 (DesignSystem module, catalog, `aiWorking`/`aiArrived`/`aiDecided`/`aiNeedsYou` and trail), 65–66
(`rs-*`), 67 (`AddKeySheet`, `AddKeyDoneView` "Keep / Switch to…", "Switch Account or Key…" in `AppSwitcherMenu.swift`,
`AccountsSheet`), 70 (`ft-*`), 71, and the §12 language picker.

Not checked (low confidence): Analytics small-window scenes `an-funnel-s`, `an-bd-s` (no DEBUG scenes).
