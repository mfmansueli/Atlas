# For Claude Code: apply the approved Pricing and App Store preview designs to Atlas (Swift) · updated 25 Nov

Read `CLAUDE-design-rule.md` in the design-system handoff (sections "Pricing: product page and prices by country" and "On the App Store preview") and follow it. The canvas shows every state: board 73 (updated 25 Nov) and the scenes `pr-prod`, `pr-prod-why`, `pr-prod-up`, `pr-prod-filters`, `pr-prod-cols`, `pr-prod-fallback`, `pr-prod-map`, `pr-prod-hist`, `pr-prod-strat`, `pr-prod-insp`, `pr-prod-acc`, `pr-prod-start`, `pr-prod-results`, `pr-open`, `pr-prod-edit`, `pr-prod-set`, `pr-prod-sel`, `pr-prod-find`, `pr-prod-life`, `pr-prod-details`, `pr-prod-rp`, `pr-prev-menu`, `ov-event`, `sp-event`.

## 1. Pricing: open a product (and retire the old price screen)

- Remove "Edit Prices…" and the old price table. Everything it had moves to the product page below.
- Make the top of each product card one button with a trailing `chevron.right`. It pushes a product page inside Pricing with a breadcrumb "Pricing › <product name>". ⌘[ and choosing Pricing in the sidebar go back to the list.
- At the right of the breadcrumb, `chevron.up` / `chevron.down` go to the previous or next product (⌥⌘↑ / ⌥⌘↓).
- The product page has a segmented control: Prices by Country · Results · Offers · Review Screenshot · Details.
- "Show Countries" on a price suggestion opens the same page with the Suggested filter.

## 2. Prices by Country

- **Banner** (one per screen): "Suggested prices in N countries." with the Built-in source chip and "Not very sure" on the title line; below, the why and "Based on purchasing power alone: Atlas doesn't read Sales and Trends yet." Actions: a strategy pop-up, Dismiss All, Accept All N….
- **Strategy pop-up** (app-wide): Show Suggestions · Apply Recommended Prices · Keep Prices, then Customize Suggestions…, which opens an `.inspector`: method, base country and price, price index (World Bank PPP price level), fallback chain (IMF implied PPP rate → region median → Apple's automatic price, fixed last), limits (never below 30% of the base, never above Apple's automatic price, round to a price point), how sure, Use Built-in.
- Use a SwiftUI `Table` with `TableColumnCustomization`:
  - Always: Country or region (region on a second line), Price (a pop-up-style button), Change.
  - On by default: In US$ ("≈ $46"), Proceeds (the price point's proceeds), How it's set (Base price, Automatic, Set by you, Accepted suggestion, Adjusted suggestion, plus the "Not pushed" pill).
  - In a Columns menu: Feels Like ("$83 2.1×"), Equalized, Currency, Source (World Bank / IMF / Region median + Fallback pill), Reason.
- Add `.searchable` matching name, ISO code, currency or region.
- Add a segmented filter: All · Suggested · Set by You · Automatic, each with a count, and a Filters button with a count: region (Americas, Europe, Asia Pacific, Middle East and Africa), Changed Only, Increases Only, Fallback Only. When filtered, show one line ("Europe · Increases only · 2 of 40 shown") with Clear Filters.
- Make the columns sortable by country, US$, feels like and change, using `KeyPathComparator`.
- Allow multi-selection with `Set<Territory.ID>`. When rows are selected, show a bottom bar: "N selected" · Accept N Suggested · Set N to Automatic · Deselect.
- Show a suggestion in its own row: "→ R$ 129,90" in the assistant purple and a change pill (`PriceChange` in Tokens.swift: decrease gray with `arrowtriangle.down.fill`, increase amber with `arrowtriangle.up.fill`), with Accept (`checkmark`) and Dismiss (`xmark`) for that country only.
- Clicking a price or a suggestion opens a `.popover`:
  - The title is "<Country> · <Product>", with the line "Now <price> · <how it's set>".
  - Three radio choices. "Suggested price" with a −/+ `Stepper` over the territory's price points, the change pill, ≈ US$, and: "At <price> it feels like $X for local incomes, N× the US price; you get ≈ $Y.", "Why: <current price> feels like N× the US price there.", "<source> · factor 0.56 · Not very sure" ("Adjusted from <suggested>" once stepped). "Apple's automatic price": "Follows exchange rates and tax · <today's value>, ≈ $X". "A price you choose": price points for that territory (`subscriptionPricePoints` / `inAppPurchasePricePoints`), each with ≈ US$, the suggested and current ones marked.
  - The base-price territory shows only the price points, with "The base price. Countries on Apple's automatic price follow it."
  - The primary button reads "Accept <price>", "Set <price>" or "Use Automatic Price".
- Table · Map · Histogram (segmented, `tablecells` / `map` / `chart.bar.xaxis`); filters apply to all. Map: a tile grid coloured by `PriceLevel` (feels-like ratio; Now / Suggested), code and ratio as text on each tile, an aiFill ring where a suggestion waits; click opens the popover. Histogram: Swift Charts `BarMark`, countries per $5 in US$, now (systemGray) and suggested (aiFill), a dashed line at the US base price.
- Table footer: "175 countries and regions · N likely held back by price · N not pushed" and "Price changes start: Right Away ▾ / On a Date…".
- Accept All N… opens a sheet: N go down / N go up with three examples each; when it starts (right away / a date → `startDate`); where a price goes up, "Keep their current price where it goes up" for existing subscribers (on → `preserveCurrentPrice`), with an amber note when off. Primary: Add to Review & Push.
- Every change waits in Review & Push, one row per product, for example "Brazil R$ 199,90, Japan back to automatic. Applies when you push."
  - After a change, the row shows "was <old price>", the change pill and Undo.
  - A toast says "<Country>: <price> is in Review & Push." with Undo.
- When the table is narrower than 780 pt, move In US$, Proceeds and How it's set to a second line under the country name; hide optional columns. At 860 × 560 the product name and base price move into the breadcrumb row, the banner keeps one line, filter counts hide, Filters and Columns become icons, the inspector floats over the table.
- The other tabs:
  - **Results:** 3 cards (subscription starts, proceeds over 28 days, countries with enough people), then one row per country: price before → after, starts, page view → start, proceeds, Better · Worse · About the same · Too few to tell. Worse rows: Restore… (old price into Review & Push). Nothing to compare: `ContentUnavailableView`.
  - **Offers:** list introductory, promotional, win-back and offer-code offers. A one-time purchase shows "One-time purchases don't have subscription offers."
  - **Review Screenshot:** a status line (missing, capture ready, accepted, in App Store Connect) and the Review Screenshot… button.
  - **Details:** type, product ID, subscription group, base price, availability, Apple's commission, tax category, Family Sharing.

## 3. Preview in (replaces "What people pay")

- Use one country pop-up button with a "Find a country or currency" field. Group countries as "With price changes" first, then "All countries and regions". Add ‹ › buttons to go to the previous or next country with a change.
- Each product shows its price there. When the price is changing, show the old price struck through, with "Suggested" or "Not pushed", and the ≈ US$ value. Clicking a product opens its page on that country.

## 4. On the App Store preview (Overview and Store Page)

- Show the App Preview first: its poster frame, a `play.fill` button and its length. Then show every screenshot in one horizontal `ScrollView` with snapping and a fade at the trailing edge. Below the row, show "App Preview and 5 screenshots · scroll for more", using the real counts.
- Show the In-App Event card only while an event is live on the App Store. It contains:
  - the label "Happening now";
  - the event's badge, name and short description over its artwork;
  - its dates.

  The card goes under the screenshots and opens In-App Events.

## Rules

- Icons are SF Symbols only: `Image(systemName:)`.
- Copy follows the house rules:
  - Title Case for buttons, tabs and segments; sentence case for everything else;
  - buttons start with a verb;
  - glossary: suggestion, push, Review & Push.
- Don't change App Store Connect behavior beyond what's described here.
- Colours come from tokens only: `PriceLevel` and `PriceChange` in Tokens.swift (design-tokens.json → `color.priceLevel`, `color.priceChart`, `pill.change`).
- Reply with the files you changed, what you couldn't do, and any App Store Connect API you weren't sure about (`startDate`, `preserveCurrentPrice`, price point `proceeds`).
