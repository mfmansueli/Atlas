ATLAS · DESIGN HANDOFF · OCTOBER 2026

# Atlas README

A native macOS 27 app for developers who ship several apps. It localizes two things through the App Store Connect API: subscription prices, set by purchasing power to get more people to pay, and the App Store page for every language. It also covers App Information and lets the person’s own AI assistant propose changes through a local MCP server.

**How this canvas is organized.** Foundations and the two component sheets sit at the top. Below them is one interactive **Prototype**; press Play to use it. Each “States” board under it embeds that same prototype at a named state, in light, dark or Increase Contrast. Every screen therefore has one source of truth, and each tile is clickable. The dashed `Prototype` pill in the bottom-right of the prototype switches appearance, simulates connect errors and failed pushes, runs the assistant, and jumps four weeks ahead for Results. The pill is not part of the design.

1. Principles
2. Tokens
3. Type, spacing, radii, materials
4. Components → SwiftUI
5. Window and navigation
6. Connect
7. App library
8. Overview
9. Subscription Pricing
10. The pricing formula, worked
11. How the recommendation works, and what it can’t know
12. Store Page
13. App Information
14. Review & Push
15. Connected AI assistants (MCP)
16. Settings
17. System states
18. Menus and shortcuts
19. Accessibility
20. Decisions the brief left open
21. What SwiftUI can’t do as drawn
22. About the sample data

## 1 · Principles

- **Native first.** Everything is a `NavigationSplitView`, `Table`, toolbar, sheet, popover, menu, segmented `Picker`, `Form` or the Settings scene. No custom title bar, web chrome or hamburger menu.
- **Calm and dense.** 26 pt table rows, 12 pt cells, tabular digits everywhere a number appears. Most of the screen is neutral.
- **Color carries meaning only:** increase (orange), decrease (teal), error (red), warning (yellow), machine-translated (purple), unsaved (blue dot). Confidence, provenance and the assistant tag stay neutral.
- **Nothing is pushed without review.** Every change, whether you made it, a suggestion filled it, machine translation produced it or an assistant proposed it, waits in Review & Push. App Privacy is never pushed, because the API can’t write it.
- **Honest numbers.** Suggestions show their source, edition and confidence. Conversion effects are shown as directions, never as invented rates. Results compare before and after and say when there’s too little data.

## 2 · Tokens

Defined in an Asset Catalog with Any, Dark, High Contrast and Dark High Contrast appearances. The Foundations board renders every token live in all four. Wherever a system color exists, use it; the hex values are the target appearance.

| Token | Role | Light | Dark | SwiftUI / AppKit |
| --- | --- | --- | --- | --- |
| window | Behind the sidebar pane | #EFEFF2 | #1E1E21 | `windowBackgroundColor` |
| content | Tables, editors | #FFFFFF | #161618 | `textBackgroundColor` |
| raised | Cards, popovers, sheets | #FFFFFF | #2A2A2E | `controlBackgroundColor` |
| label / -2 / -3 | Text levels | #1D1D1F · #6B6B70 · #9A9AA0 | #F2F2F5 · #A3A3AA · #6E6E75 | `.primary / .secondary / .tertiary`. Secondary is darker than the system’s so 11 pt grey still passes 4.5:1 |
| sep / sep-2 | Separators, control edges | black 9% / 16% | white 9% / 16% | `separatorColor` |
| fill-1…3 | Chips, tokens, flag tiles | black 4 / 7 / 12% | white 5 / 9 / 15% | `.fill.tertiary` etc. |
| accent / accent-text | Prominent buttons, links | #0071E3 / #0066CC | #0A72E8 / #4DA3FF | `controlAccentColor` (follows the user’s accent) |
| inc | Price increase | #A84800 · mark #E86E00 | #FFA552 · #FF9F40 | custom |
| dec | Price decrease | #00727C · mark #0096A5 | #5CD6E0 · #46CDDC | custom |
| err | Error, over a limit | #C8102E | #FF7A70 | `systemRed`, darkened for text |
| warn | Warning, fallback, stale | #7A5600 on yellow 20% | #FFD34D | `systemYellow` as the mark |
| mt | Machine-translated, not reviewed | #7A35B0 | #D4A3FF | custom |
| unsaved | Not pushed | accent | accent | an 8 pt dot |

Increase Contrast swaps glass for opaque fills, darkens separators to 30–55%, deepens the accent to #0040DD (light) and gives pills a 1 pt border in their own color.

## 3 · Type, spacing, radii, materials

- **Type:** the system font (SF Pro) and SF Mono only. Large Title 26/32 (Connect only), Title 1 22/28 semibold, Title 2 17/22, Title 3 15/20, Headline 13/16, Body 13/16, Callout 12/15 (table cells), Subheadline 11/14, Footnote 10/13. Prices, IDs, counts and percentages use `.monospacedDigit()`; bundle IDs, product IDs, tokens and code use `.monospaced`.
- **Spacing:** 2, 4, 6, 8, 12, 16, 20, 24, 32.
- **Radii:** flag tile 3, badge 5, field and keyword 7, banner and menu 10, card 12, popover 14, sidebar pane and sheet 18–20, window 24 (system), and capsules for buttons, segmented controls and pills.
- **Materials:** Liquid Glass only in the navigation layer: toolbar controls and the sidebar pane, which is the system default. Content is never glass.
- **Metrics:** window 1200×780 by default, minimum 860×560. Sidebar 256, inspector 300, toolbar 52. Table header 28, row 26. Controls 20 / 24 / 30. Pointer metrics, not 44 pt touch targets: this is a desktop app.

## 4 · Components → SwiftUI

| Component | Built from | Notes |
| --- | --- | --- |
| Territory row | `Table` row, `TableColumn`s | Native selection; on a selected row, pills switch to white on 20% white via `@Environment(\.backgroundProminence)`. |
| Price cell | `VStack` of two `Text`s | Customer price; proceeds after commission and tax; USD equivalent. |
| Delta pill | Capsule label | Teal ▼ / orange ▲, always signed. Rounded to whole percent. |
| Price-point stepper | `Stepper` with `onIncrement/onDecrement` + a button label | Moves only between Apple’s price points. The label opens the breakdown popover. |
| Status badge | `Label` | Unchanged · Recommended (lightbulb) · Edited manually (pencil) · Custom (sliders) · Scheduled (calendar) · Excluded (nosign). |
| Pricing mode picker | `Menu` in the section bar; first-time `.sheet` with three radio cards | Show suggestions is preselected and marked Recommended. |
| Suggestion cell | Button → `.popover` | Price, three-bar confidence, “feels like” today and suggested, reason, what it’s based on. |
| Confidence badge | Three bars + text | Low = purchasing power only; Medium = your sales; High = an earlier change in that territory. |
| Index source row | Radio-style rows in the inspector | Publisher, edition, coverage “n of 175”, description, source link, stale and newer-edition flags. |
| Provenance badge | Small label | Filled = chosen index; outlined = a fallback filled the gap. |
| Tier chip | Outlined capsule | T1–T4 with its percentage. |
| Price breakdown popover | `.popover(arrowEdge: .trailing)` | A one-line summary, numbered steps and nearby price points; Reset to Equalized, Exclude from Index. |
| Source comparison bars | `Gauge` or custom bars | Current, equalized and each index; “Use this” turns the row into a manual edit. |
| Locale chip | Flag + name | The app uses the regional-indicator flag; the canvas uses a code tile. Primary and RTL tags. |
| Character counter | Trailing `Text` | Characters for most fields, UTF-8 bytes for keywords. Over the limit: red pill, red field outline, and the change can’t be pushed. |
| Keyword token | `NSTokenField` (wrapped) or a flow layout | Duplicate = yellow; already in the name or subtitle = struck through; Optimize removes both plus spaces after commas. |
| Coverage cell | Button in a `Grid` | Filled · Missing · Over · MT · Edited · Proposed by an assistant. |
| Drop zone | `.dropDestination(for: URL.self, isTargeted:)` | Empty · hover · imported · wrong file. |
| Inline message, banner | `Label` under a field; banner in a `.safeAreaInset(edge: .top)` | Banners: offline (neutral), rate-limited (warning), API error with Apple’s detail (error), partial failure (error). |
| Inspector section | `.inspector` with `DisclosureGroup`s | Strategy and Territory tabs. |
| Review row, progress row | `List` rows in the review sheet | Checkbox, label, old → new, source tag, discard. Progress: queued ○, sending (spinner), done ✓, failed with Apple’s code. |
| Assistant provenance tag | Outlined capsule with a monogram | “Proposed by Claude Code”. Neutral, separate from the MT purple and the unsaved dot. |
| Evidence popover | `.popover` | What, why, evidence lines (file:line, SDK, Info.plist key), what it couldn’t see; Reject / Confirm. |
| Activity indicator | `ToolbarItem` with a `ProgressView` | “Claude Code is proposing changes · 12 so far”. Never modal. |
| Connected-client row, copyable command | `Form` rows; `Text(...).textSelection(.enabled)` + Copy button | The command shows a masked token until “Show”. |
| Age rating question row, rating preview | Segmented `Picker` per row; preview card | None / Infrequent / Frequent, or No / Yes. |
| Privacy data type row, label preview | `DisclosureGroup` per type | Purposes, linked, tracking, source and a Confirmed checkbox. |

## 5 · Window and navigation

- **One main window** (`WindowGroup`, but single-instance) and the `Settings` scene (⌘,).
- `NavigationSplitView`: the sidebar is the app library; the detail is the selected app; Pricing adds an `.inspector`.
- **Toolbar:** app name and bundle ID · a segmented picker *Overview | Subscription Pricing | Store Page | App Information* (⌘1–⌘4) · the assistant indicator while one works · Refresh and Activity · **Review & Push** with the pending count across all apps (prominent glass when the count is above zero).
- Each section has its own **section bar** under the toolbar: what’s being edited (subscription or version), a view picker, and section actions. Pricing mode and Customize… live there; the brief calls it the “Pricing toolbar”.

## 6 · Connect

- Shown at first launch and after the last key is removed. Centered column, max 500 pt: Issuer ID (UUID), Key ID (10 characters), private key drop zone, “Where do I find these?” disclosure, error area, trust note, Connect.
- **Validation** runs when a field loses focus: “An Issuer ID is a UUID: 8-4-4-4-12 hexadecimal characters…”, “A Key ID is 10 capital letters and digits…”. The key ID is uppercased as you type.
- **Drop zone**: empty → hover (accent dashed border, “Release to import”) → imported (file name, “Stays in this Mac’s Keychain”, Remove) or wrong file (“notes.txt isn’t a .p8 private key…”).
- **Connect** is disabled until all three are valid. Checking shows a spinner. Errors: **401** key rejected; **403** role too low, needs Admin or App Manager; **offline**, with Try Again.
- **Help:** Users and Access → Integrations → App Store Connect API → Team Keys; Admin or App Manager; copy the Issuer ID and Key ID; the .p8 downloads only once; link to App Store Connect.
- **Trust note:** the key never leaves the Mac; it’s in the Keychain and every request is signed locally (ES256 JWT, 20-minute lifetime).
- **First sync:** “Loading your apps…” with progress across apps, then the library opens on the first app’s Overview.

## 7 · App library (sidebar)

- **Account switcher** at the top: team name, role and key ID; a menu of saved keys plus “Add Another Key…” and “Manage Keys…”.
- **Search** by name, bundle ID or SKU. **Sort**: Name, Unpushed changes, Lowest locale coverage, Most price suggestions.
- **Row:** icon (gradient from App Store Connect, or a letter tile), name, bundle ID in mono. Indicators: blue dot before the name for unpushed changes; a coverage ring with the locale count; a tag with the number of territories whose price likely holds people back. The tag is hidden for apps set to Keep my prices.
- **States:** loading skeleton, empty account, error with Try Again, no search matches.

## 8 · Overview

Header with the icon, name, bundle ID, SKU and current version, plus quick actions (Review Suggestions, Translate Missing…, Review & Push). Cards in an adaptive grid (min 270): **Subscriptions** (groups, durations, base prices) · **Territory prices** (equalized vs custom) · **Pricing** (mode; unless kept, the number of territories that likely hold people back, with Review Suggestions) · **Store page** (locales, completeness, missing/MT/over) · **App Information** (age rating, App Privacy status, App Review completeness) · **Pending changes** · **Last push**.

## 9 · Subscription Pricing

### Section bar

- **Subscription browser** (button → popover): groups → subscriptions with name, product ID, duration, review state and base price; in-app purchases below.
- **Prices | Offers | Results**; there are no Offers for in-app purchases.
- **Pricing mode** menu and **Customize…** (toggles the inspector; hidden in Keep my prices).

### Pricing mode

- The first time Pricing opens for an app, a sheet asks; *Show suggestions* is preselected. The default for new apps is in Settings.
- **Keep my prices:** read-only table (price, proceeds, USD, equalized, custom or equalized). Sidebar and Overview drop their pricing indicators; Review & Push holds text only; the assistant’s `propose_prices` is refused. The only nudge is “Show price suggestions” in the bottom bar.
- **Show suggestions:** suggestion columns, nothing queued. Apply per row, per selection, or **Apply Recommended Prices…** in the bottom bar.
- **Apply recommended prices:** fills every proposed price and opens Review & Push. It stays the mode, so future suggestions arrive pre-filled, still behind review.

### Price matrix

- 175 rows, sortable. The default sort is **product page views**, so the territories where people actually look come first (US, India, Brazil, Germany…). Without sales data it falls back to name.
- **Column presets** (Columns menu), because 17 columns don’t fit at 1200 pt:
  - *Suggestions*: Territory · Current · Feels like · Suggested + confidence · Reason · Proposed · Change · Status.
  - *Price index*, automatic while the inspector is open: Territory · Current · Equalized · Factor (+ tier) · Source · Proposed · Change.
  - *Prices and proceeds*, the Keep my prices default: Territory · Region · Currency · Price · Proceeds · USD · Equalized · Pricing.
  - *All columns*: everything, scrolling horizontally. In SwiftUI, any column can also be hidden from the header’s context menu (`TableColumnCustomization`).
- **Filters:** region (All, Americas, Europe, Asia Pacific, Africa & Middle East), Changed only, Increases only, Fallback only, search by territory, code or currency.
- **Selection:** click, ⌘-click, ⇧-click. The bottom bar shows the count, Apply Suggestion and More: multiply by 0.9 / 0.8 / 1.1, set to feel like the base price, reset to equalized, copy from Monthly × ratio, apply the strategy to the whole group keeping the annual-to-monthly ratio, select all, clear.
- **Proposed price** is a stepper over price points; its value opens the breakdown popover with nearby points. There is never a free-form price.
- **Bottom bar:** “n of 175 territories · n likely held back by price · n pending”, the selection actions, **Starts now ▾** (schedule) and Apply Recommended Prices….

### Visualizations

- **Tile map**: one 20 pt tile per territory, placed near its longitude and latitude, colliding tiles nudged to the nearest free cell. It’s colored by % vs base, USD equivalent, “feels like” or index factor, with hover details. A geographic map would hide Singapore, Luxembourg and the Caribbean.
- **Histogram**: territories bucketed by distance from Apple’s equalized price, in 10% steps; teal below, orange above, with the median and counts.

### Strategy inspector (Customize…)

Method (Recommended, Apple equalization, Price index, Custom regional tiers) · base territory and price · price index picker · fallback chain · intensity · floor, ceiling and minimum proceeds · discount only · tiers · excluded territories · rounding (Auto per currency, .99, .90, round) · never raise · the formula · index data freshness with “Update Index Data”. Changing anything turns the strategy Custom and shows **Back to Recommended**. The matrix updates live. A **Territory** tab shows the selected territory’s breakdown, source comparison bars and an Exclude switch.

### Schedule and subscribers

A sheet from the bottom bar or the review sheet: start now or on a date; “Keep the current price for existing subscribers”; for increases, a warning with a count of existing subscribers per territory, because Apple may require them to agree before renewal.

### Results

Each territory changed in a push is compared over the 28 days before and the 28 days after: subscription starts, product page view → start conversion, and proceeds (USD, after commission and tax). **Better** means more starts and at least the same proceeds; “More starts, less proceeds” is neutral; **Worse** offers Restore, which queues the old price for review. Territories with fewer than 10 starts on both sides are counted as “Too little data”. Until day 28 the tab says it’s too early and when results arrive.

### Offers and in-app purchases

Offers: list (introductory, promotional, win-back, offer codes) plus one editor; offer prices are derived from each territory’s subscription price and snapped to price points. In-app purchases use the same matrix with no offers and no subscriber options.

## 10 · The pricing formula, worked

One formula for every source:

```
factor = territory price level ÷ base territory’s price level
target = equalized local price × (1 − intensity + intensity × factor)
target = clamp(target, floor, ceiling)          // floor and ceiling are % of the base price
price  = nearest price point to target, with the preferred ending
         (when the floor applied, the nearest point at or above the floor)
```

Starting from Apple’s equalized price, not from a currency conversion, keeps Apple’s tax handling. Floor and ceiling are a share of the base USD price, converted with the same equalization multiplier.

#### Brazil, Recommended (World Bank PPP, intensity 100%, floor 30%)

```
Base: United States, $39.99 a year
Equalized:  R$ 219,90
Factor:     0.50                       (World Bank price level, Brazil ÷ US)
Target:     219,90 × (1 − 1 + 1 × 0.50) = R$ 109,95
Floor:      30% × $39.99 = $12.00 → R$ 65,98     above it
Price:      nearest point ending ,90 → R$ 109,90  (−50%)
Feels like: 219,90 ÷ 5.5 ÷ 0.50 = $80 today → 109,90 ÷ 5.5 ÷ 0.50 = $40
```

#### Brazil, Customize: Big Mac Index, World Bank fallback, intensity 80%, floor 35%

```
Factor:  0.75 (Big Mac, January 2026 edition)
Target:  219,90 × (1 − 0.8 + 0.8 × 0.75) = 219,90 × 0.80 = R$ 175,92
Floor:   35% of base = R$ 76,98 → above it
Price:   R$ 174,90
At 100%: 219,90 × 0.75 = R$ 164,93 → above floor → R$ 164,90
```

#### Japan, excluded

The Big Mac Index puts Japan at 0.55 because of the weak yen, which would cut ¥6,000 to ¥3,300 in a market that already pays well for apps. Excluded territories stay at the equalized price, and their badge says Excluded.

#### Snapping

Prices only ever land on Apple’s points, about 800 per currency, which the app fetches per territory and caches. Auto ending uses each currency’s usual ending: ,90 for BRL; .99 for USD, EUR and GBP; round numbers for JPY, KRW and THB; endings in 9 for MXN, NOK, SEK, DKK and CZK; 9.000 for IDR and VND; 8 for CNY and HKD.

## 11 · How the recommendation works, and what it can’t know

1. **Purchasing power** (always available): the formula above with World Bank PPP at full intensity, floor 30%, discount only. “Feels like” = local price ÷ equalization multiplier ÷ factor, in base-currency terms.
2. **Your sales**, when the key’s role can read Sales and Trends and App Analytics: product page views and subscription starts per territory over 28 days. With at least 1,000 views and 15 starts, confidence becomes **Medium**. If the price feels high but conversion is still at least 75% of the base territory’s, the step is halved: “converts well, smaller step”. If conversion is under 60% of the base’s, the reason says “many page views, few starts”.
3. **Earlier changes** in that territory: confidence becomes **High**. If an earlier cut didn’t lift starts, the suggestion holds the current price (“Last cut didn’t lift starts · holding”).

A territory “likely holds people back” when its current price feels at least 25% above the base price.

**What it can’t know.** App Store Connect can’t A/B test prices, so nothing here proves a price change caused a result. Seasonality, featuring, marketing, competitors and exchange-rate moves all move the numbers. Price indices measure the cost of a basket of goods, not what people pay for apps. They lag (World Bank by a year or two), and none covers all 175 territories. Small territories sell too little to learn from. So the app never shows a predicted conversion rate: it shows a direction, the basis and a confidence level. Results are framed as “compares, doesn’t prove”.

## 12 · Store Page

- **Context bar:** version picker (1.4 Prepare for Submission, editable; 1.3 Ready for Distribution, live and read-only) and a line explaining that Name, Subtitle and Privacy URL are app-level while the rest is per version. Views: Coverage | Editor | In-App Texts | Screenshots.
- **Action bar:** Translate Missing…, Fill (copy from a sibling locale, send What’s New to every locale, find and replace), Import & Export (CSV, XLIFF, JSON), Add Locale, plus a summary line.
- **Coverage grid:** locales × 9 fields, grouped under “App information · all versions” and “Version 1.4”. Cells: filled (count), missing, over the limit or invalid URL, machine-translated, edited, proposed by an assistant. A cell opens the editor.
- **Editor:** the primary locale read-only on the left, the target locale editable on the right, field by field, with live counters. RTL locales get `.environment(\.layoutDirection, .rightToLeft)` and right-aligned fields; URLs stay LTR. URLs are validated as full https addresses. Limits: Name 30, Subtitle 30, Promotional Text 170, Description 4,000, What’s New 4,000, Keywords 100 bytes.
- **Keyword editor:** tokens with a byte counter (accented letters and CJK cost 2–3 bytes), duplicates flagged, words already in the name or subtitle struck through, spaces after commas counted. “Optimize · saves n bytes”.
- **Translation:** missing fields only; scope by field, locale or everything; provider (Apple Translation on this Mac, an AI provider with App Store-optimized keywords, or your assistant via MCP); glossary of brand terms; tone. Suggestions are shown against the current text and accepted or rejected per field. Accepted text stays tagged machine-translated until reviewed; editing it counts as reviewing.
- **In-app product texts:** group name, subscription display names (30) and descriptions (45), and in-app purchase names, per locale.
- **Screenshots:** read-only strip per locale and device size; missing flagged; locales without iPhone screenshots fall back to the primary locale.
- **Import:** shows a diff with a checkbox per change before applying, and lists problems (unknown locale codes, over-limit values).

## 13 · App Information

A fourth section (⌘4) with a page column: General · Age Rating · App Privacy · App Review · Export Compliance. Each row shows a badge (rating, privacy status, Complete or Missing, Exempt) and a dot for unpushed edits. Edits become pending changes and go through Review & Push. App Privacy is the exception.

- **General:** primary and secondary category, with up to two Games subcategories; content rights (third-party content, rights confirmed); per version: copyright, release (manually, automatically after approval, on a date).
- **Age Rating:** Apple’s 2025 questionnaire with 4+, 9+, 13+, 16+ and 18+. Content is None / Infrequent / Frequent: violence (three levels), sexual content, profanity, horror, mature themes, alcohol/tobacco/drugs, weapons, medical, health and wellness. Capabilities are Yes / No: messaging, user-generated content, social media, advertising, unrestricted web access, parental controls, age assurance. Then gambling, contests and loot boxes. A live preview shows the rating, the current value in App Store Connect, and the Australian, Brazilian (self-rated) and Korean ratings. An override rates higher, with a reason. Assistant answers carry evidence and a Confirmed checkbox.
- **App Privacy:** see section 15b.
- **App Review:** contact first and last name, phone, email; Sign-in required with a user name and a masked password (Show / Hide, stored in the Keychain); notes with a 4,000-character counter.
- **Export Compliance:** uses encryption? all of it exempt? proprietary algorithms? third-party encryption? available in France? Plus the note that `ITSAppUsesNonExemptEncryption = NO` in Info.plist skips the question for every build.

## 14 · Review & Push

- **Review sheet** (⇧⌘P, 800 pt): scope “This app · n | All apps · n”; source filter All · You · Machine translation · Claude Code; changes grouped by app → section → territory or locale, each as old → new with its source tag, a checkbox and a discard button. Price sections show the schedule line with Edit…. **Push Selected** and **Push n Changes**; an estimate of requests and time.
- **Blocked rows** (over a limit, invalid URL, unresolved conflict) say why and are skipped.
- **Conflicts:** if a value changed in App Store Connect since the last fetch, both are shown and you choose. If you and an assistant both edited a field, both versions are shown and you pick one.
- **Progress:** the same sheet turns into a progress list, each row going queued → sending → done or failed, with Apple’s error code. A rate-limit meter shows requests used this hour out of 3,600; requests are sent one at a time. Cancel Remaining; when done, Retry Failed, View Results (if prices changed) and Done. You can keep working while it runs.
- **Activity** (toolbar clock): timestamped pushes with results, failures, Results and Restore Previous Values (which queues the old values for review).

## 15 · Connected AI assistants (MCP)

Atlas runs a local MCP server on this Mac. The person’s own assistant connects to it, does the thinking on its own plan, and uses Atlas to read and to *propose*. Atlas keeps the API key, validates every value and queues it. Assistants never see the .p8 and can’t push.

### Transport and setup

- Streamable HTTP on `http://127.0.0.1:47321/mcp`, loopback only, with a bearer token. For clients that launch servers as processes (Claude Desktop, Codex), the app bundle ships a small stdio bridge, `atlas-mcp`, that forwards to the running app.
- Claude Code: `claude mcp add --transport http atlas http://127.0.0.1:47321/mcp --header "Authorization: Bearer …"`. Claude Desktop and Cursor get JSON; Codex gets `config.toml`.
- Assistants connect only while Atlas is open. Regenerating the token disconnects every client.

### Tools

| Tool | Input | Output |
| --- | --- | --- |
| list\_apps | — | `[{appId, name, bundleId, sku, pricingMode, locales, pendingCount}]` |
| get\_listing | `appId, version?, locale?` | Each field’s value, limit, level (app or version) and state (filled, missing, over, mt, edited, proposed) |
| list\_missing\_translations | `appId, version` | `[{locale, field, limit, sourceText}]` |
| propose\_listing\_text | `appId, version, locale, field, value, reason?` | `{status: "queued" | "refused", changeId?, reason?}`. Refused when over the limit, the locale is unknown, the URL is invalid or there’s no editable version |
| get\_prices | `appId, productId, territories?` | Per territory: currency, current, proceeds, equalized, suggested, factor, source, confidence |
| get\_price\_points | `appId, productId, territory, near?` | `[{price, proceeds}]` around the value |
| propose\_prices | `appId, productId, prices: [{territory, price}], reason?` | Per item queued or refused. Always refused for Keep my prices; a value that isn’t a price point is refused with the nearest two |
| get\_app\_info | `appId, version?` | Categories, content rights, copyright, release, App Review details (password never returned), export compliance |
| propose\_app\_info | `appId, fields, reason?, evidence?` | Queued or refused per field |
| get\_age\_rating | `appId` | Answers, calculated rating, regional ratings, override |
| propose\_age\_rating | `appId, answers: {question: value}, evidence: {question: [string]}, couldNotSee?` | Queued answers |
| get\_privacy\_draft | `appId` | Status (draft, confirmed, entered), items, last scan |
| propose\_privacy\_answers | `appId, collects, items: [{type, subtype, purposes[], linked, tracking, evidence[]}], couldNotSee` | Draft items tagged with the client; marks a confirmed draft “Out of date” when they disagree |
| propose\_review\_details | `appId, contact?, demoAccount?, notes?` | Queued |

**Prompts**, which Claude Code shows as slash commands: `/mcp__atlas__translate_missing`, `fill_privacy_from_code`, `fill_age_rating`, `whats_new_from_git`. Each tells the assistant what to read in the project (PrivacyInfo.xcprivacy, Package.resolved and SDK privacy manifests, Info.plist usage strings, entitlements, ATT, web views, chat or AI features, CryptoKit and other crypto use, `git log` since the last release tag) and to always report what it couldn’t see.

### Permission model

- The server is off by default and listens only on loopback; every request needs the token.
- Read access is always on while the server runs. Proposing store text, prices and app information are separate switches in Settings → AI Assistants.
- There is no push tool and no tool that returns the private key or the App Review password. Only the person pushes, from Review & Push.
- Every value goes through the same validation as a manual edit. Refusals come back with a reason the assistant can act on.
- Every call is logged (time, client, tool, target, read, proposed or refused, and why).
- Proposals carry the client’s tag through review and history; Reject All from an assistant discards its proposals in one step.

### 15b · App Privacy, which the API can’t write

The App Store Connect API has no endpoint for the App Privacy label. So this page is an assisted checklist:

1. **Draft:** answers are typed by hand or proposed by the assistant, with evidence and “what it couldn’t see” (for example, data a server collects isn’t visible in the app’s code). Each answer has a Confirmed checkbox.
2. **Confirmed** once every answer is checked. The page then lists the steps in the order Apple asks, with Copy Steps and Open in App Store Connect.
3. **Entered** after “Mark as Entered”.
4. **Out of date** when a newer scan finds something the entered answers don’t include, for example a new analytics SDK.

A label preview (Data Used to Track You, Data Linked to You, Data Not Linked to You) mirrors the App Store. The privacy policy and privacy choices URLs are linked here and do push.

## 16 · Settings

- **Account:** saved keys with issuer ID, key ID and a role check (can read Sales and Trends or not); Test Connection; Remove…; Add Another Key….
- **Pricing:** pricing mode for new apps (Show suggestions by default); use sales data; base territory; rounding; default index, fallback chain, intensity, discount only; floor and ceiling; never raise; bundled index snapshot date, automatic or manual updates, saved custom indices.
- **Translation:** provider (Apple Translation, AI provider with API key, your assistant via MCP), glossary, source locale, tone.
- **AI Assistants:** server switch and status (Off · Waiting for a client · Running), per-client setup with a copyable command, access token with Show, Copy and Regenerate, connected clients with last activity and Disconnect, permissions, the prompts list, and the activity log including refused calls.
- **General:** confirm before pushing (always, over 50 changes, never), confirm before discarding, ask before pushing price increases; the commission used for proceeds (15% Small Business Program or 30%).

## 17 · System states

- **Skeletons:** sidebar rows, overview cards, table rows during refresh.
- **Banners:** offline (“Edits stay queued on this Mac”), rate-limited (“resumes at 12:00; nothing is lost”), API error with Apple’s code and detail, partial failure (“2 of 26 failed… Review Failed”).
- **Empty states:** no subscriptions; no editable version (only the live version exists; create one in App Store Connect; app-level fields stay editable); a locale with no content (Translate from English or copy URLs); no sales data (banner: suggestions use purchasing power alone, all low confidence); too little data in Results; nothing to push.

## 18 · Menus and shortcuts

| Menu | Commands |
| --- | --- |
| Atlas | Settings… ⌘, · Add Another Key… |
| File | Import Translations… ⇧⌘I · Export as CSV / XLIFF / JSON · Import Custom Index… |
| Edit | Find ⌘F (focuses the current section’s search) · Find and Replace Across Locales ⌥⌘F |
| View | Overview ⌘1 · Subscription Pricing ⌘2 · Store Page ⌘3 · App Information ⌘4 · Show Inspector ⌥⌘I · Table / Map / Histogram · Columns ▸ · Refresh ⌘R |
| Pricing | Pricing Mode ▸ · Apply Suggestion to Selection · Apply Recommended Prices… · Reset to Equalized · Schedule… |
| Store Page | Translate Missing… ⇧⌘T · Add Locale… · Mark Reviewed |
| Push | Review & Push… ⇧⌘P · Retry Failed · Activity |

## 19 · Accessibility

- **VoiceOver row labels** read the whole row: “Brazil, current R$ 219,90, proposed R$ 109,90, down 50 percent, recommended, medium confidence”. Cells keep their own labels for column navigation.
- **Pills** speak their meaning: “Decrease, 50 percent”, “Over the limit, 31 of 30 characters”, “Machine-translated, not reviewed”, “Proposed by Claude Code”.
- **Coverage cells:** “German, Subtitle: over the limit”. Tile map tiles: “Brazil: R$ 109,90”.
- The stepper’s actions: “Lower price point”, “Higher price point”. Confidence bars are hidden from VoiceOver; the text label carries the meaning.
- Color is never the only signal: arrows and signs on deltas, icons on states, text on every badge. Contrast is at least 4.5:1 for text, including 11 pt secondary labels. Increase Contrast and Reduce Transparency are supported.

## 20 · Decisions the brief left open

- **Overview is the first toolbar segment** (⌘1), so ⌘1–⌘4 line up with the four sections.
- **Pricing mode and Customize sit in the Pricing section bar,** not the window toolbar, so the toolbar fits at the 860 pt minimum.
- **Default sort by page views,** and **column presets** instead of 17 always-on columns.
- **Increase orange, decrease teal,** never red and green: a lower price isn’t an error, and the two differ in lightness as well as hue.
- **Confidence, provenance and the assistant tag are neutral.** No new color was added for assistants.
- **The review count in the toolbar covers all apps;** the sheet opens scoped to the selected app with an All apps switch.
- **Over-limit and invalid values stay pending but can’t be pushed,** so nothing reaches Apple only to be rejected.
- **Assistant proposals are queued as pending changes** and reviewed like any other. Rejecting removes them; there is no extra accept step, because the review sheet is the gate.
- **When the floor applies, rounding goes up** to the nearest point at or above the floor.
- **Sales data adjusts the step size, not just the confidence,** and an earlier cut that didn’t help holds the price.
- **Proceeds assume the 15% Small Business Program,** switchable in Settings.
- **A tile map instead of a geographic map** (see section 9).
- **Flags are code tiles on the canvas**; the app uses system flag glyphs.
- **Results use 28-day windows** and plain verdicts, with Restore going through review.
- **App Privacy has its own states** (draft → confirmed → entered → out of date), and only an assistant scan can mark it out of date.
- **Machine-translated tags clear on any edit**, as well as on Mark Reviewed.
- **MCP on loopback HTTP with a stdio bridge**, off by default, available only while the app runs; no login item.
- **Settings is 760 pt wide** with five toolbar tabs, and each tab sizes to its content.

## 21 · What SwiftUI can’t do as drawn

- **Keyword tokens with per-token states** need `NSTokenField` through `NSViewRepresentable`, or a custom flow layout over a plain text field. SwiftUI has no token field on macOS.
- **Popovers anchored to a Table cell** work with `.popover` on the cell’s content, but the table can’t scroll the row into view for you; scroll with `ScrollViewReader` first when opening from the keyboard.
- **Pills on selected rows** need `backgroundProminence`; custom backgrounds inside `Table` rows don’t invert automatically.
- **Two-level column headers** (“App information” over three columns in the coverage grid) aren’t supported by `Table`. Use a `Grid` with a pinned header, or put the group in each column title.
- **The tile map** is a custom `Canvas` or `Grid`; MapKit can’t color 175 territories as tiles.
- **Toolbar width:** at the minimum width the segmented picker and Review & Push can’t both fit with the title, and macOS moves items into the overflow menu. Give the picker `ToolbarItem(placement: .principal)` so it stays.
- **The sheet that turns into a progress list** works as one view with two states. macOS sheets don’t animate size changes well, so keep it at a fixed size.
- **A local MCP server** in a sandboxed app needs the `com.apple.security.network.server` entitlement, and the stdio bridge needs to be a signed helper inside the bundle. Mac App Store distribution may need a review note explaining the loopback server.
- **Liquid Glass** in the canvas is approximated with a translucent fill and blur; use the system materials (`.glassEffect()`, `.buttonStyle(.glass)`, `.glassProminent` for Review & Push) rather than copying the values.
- Global shortcuts and menus can’t be shown in the HTML prototype; they come from `.commands`.

## 22 · Custom Product Pages · added November 18

**Product Pages** is a section of its own in the sidebar (Store Listing, after Screenshots, ⌘4). It lists every custom product page beside the default one with its funnel, edits each per language (promotional text, keywords chosen from the approved version’s, screenshots and App Previews per device, a deep link), makes a page’s screenshots with Autopilot, takes whole-page suggestions from the assistant with their evidence, and sends a page through Review & Push and App Review.

- Boards **50–55** on the page *Custom Product Pages*, static, at 1200 × 780 and 860 × 560.
- The shortcuts after ⌘3 each move by one: In-App Events ⌘5, App Information ⌘6, Pricing ⌘7, Reviews ⌘8, Analytics ⌘9.
- Specs, reused components, the decisions the brief left open and what to confirm in the API are in **README — Custom Product Pages** on that page.

## 23 · About the sample data

The prototype uses **illustrative sample data**: the apps, sales, subscriber counts, results, exchange rates, tax rates, equalization multipliers and every index factor (Big Mac, World Bank, IMF) are approximations chosen to make the flows realistic, not published values. The price-point ladder is simulated from per-currency rules. The real app reads price points and equalized prices from App Store Connect, sales from Sales and Trends and App Analytics, and index values from its bundled snapshot of each publisher’s data. The regional age ratings follow the shape of Apple’s tables, but the mapping in the prototype is approximate.

Sources for index definitions: [The Economist, Big Mac Index](https://www.economist.com/big-mac-index) · [World Bank, price level ratio of PPP conversion factor](https://data.worldbank.org/indicator/PA.NUS.PPPC.RF) · [IMF, implied PPP conversion rate](https://www.imf.org/external/datamapper/PPPEX@WEO) · [Apple, age ratings reference](https://developer.apple.com/help/app-store-connect/reference/age-ratings).
