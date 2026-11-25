# Pricing · region price tests (Phase 6) — questions for Claude Design

Status: plan only, nothing built (25 Nov 2026). Today a suggestion can only reach **Sure** after a past
price change in that country (28 days each side, ≥ 30 starts each side, 90% interval excluding zero).
A region price test makes that evidence on purpose: lower (or raise) one region for 4 weeks, then read
the result in the product page's **Results** tab.

## What Atlas can do with Apple's API

- A test is two ordinary price schedule changes: the new prices with a `startDate`, and 28 days later
  the old prices back (or kept, if it won). Both go through Review & Push like any price change.
- Existing subscribers: a lower price applies to them at renewal; a higher one needs
  `preserveCurrentPrice` (on by default in the Accept All sheet).
- Results reuse what exists: `PriceChangeHistory` records both changes, the 28-day windows are kept,
  and the verdict is Better · Worse · About the same · Too few to tell.
- Apple has no A/B testing for prices: the comparison is before vs during, in the same countries, so
  seasonality and campaigns can fool it. A control region (same 28 days, unchanged price) helps.

## Questions

1. **Where does a test start?** From the banner's strategy pop-up ("Test a Lower Price…"), from the
   Results tab's empty state, or from a region row's context menu in Prices by Country? One entry point
   or several?
2. **Setup sheet.** What does the person choose: region (Americas · Europe · Asia Pacific · Middle East
   and Africa) or hand-picked countries; how much lower (e.g. −20%, or "to purchasing power");
   4 weeks fixed or 2–8? Do we show the expected sample ("Europe had 2,100 page views in 28 days — enough
   to tell a 1-point change") before it starts, and refuse a test that can't reach 30 starts?
3. **Control region.** Do we pick one automatically (most similar traffic, unchanged price) and show it,
   or leave it out to keep the sheet simple?
4. **Safety level.** A test changes live prices twice. Is it risk level 3 (confirmation sheet: what,
   who, when, how to undo) once, with the end change queued automatically, or does the end change wait
   in Review & Push for the person to push again?
5. **While it runs.** Which surface shows "Day 9 of 28" — a row on the product card, the Results tab,
   the sidebar needs-you dot? At most one loop on screen: does it use `working` motion or none (it's not
   AI)?
6. **Ending it.** At day 28: a card "Europe test: Better, fairly sure — keep −20%?" with Keep New Prices
   (blue) · Restore Old Prices? What if the person pushes another price change in that region mid-test
   (end the test, warn, or block)?
7. **Verdict words.** Results today says Better · Worse · About the same · Too few to tell. Should a test
   add the effect with its range ("+1.8 points, 90% range +0.6 to +3.0") on the row, or only in details?
8. **Assistant.** Can the assistant propose a test over MCP (propose_price_test), shown as a suggestion
   card with how sure, the person starting it? Or tests are person-only?
9. **Several products.** One test per region at a time across all products of a subscription group, or
   per product?
10. **Copy.** Name: "price test", "region test" or "test a price"? (Words list: suggestion, push,
    Review & Push, Autopilot…)

## Other open design questions from the Phase 1–5 build (25 Nov)

- Prices by Country summary line (zero suggestions): blue accent like a section summary, or the grey
  secondary text used now?
- "Borrowed from Europe" — right wording for pooled evidence? When some countries borrow, should the
  banner's "N countries borrow from their region" line win over "Based on your sales in N countries"?
- Source column now reads "World Bank 2025" / "IMF, Oct 2026" (board 73: "World Bank"). Is that width OK?
- Should the exchange-rate line ("Rates by ExchangeRate-API · 25 Nov 2026") also show in Settings → Price data?
- "Checking Apple's prices…": plain line in the banner slot, or inside the banner's grey surface?
- A failed price-point read on a product card: offer Try Again there?
- Results "Too few to tell" covers both thin data and under 100 page views: say which applied?
