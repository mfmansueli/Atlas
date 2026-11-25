# Price index and exchange rate snapshots

`fetch_price_index.py` downloads the purchasing-power indices and exchange rates
Atlas ships with, checks them and writes:

- `Atlas/Screens/Pricing/Resources/PriceIndexSnapshot.json` (schema 2): World Bank,
  IMF and Big Mac price levels relative to the United States, each with its year
  and method (`exact` or `fallback`), and per source the edition (label, badge,
  provenance label, publication date, fetch date, data year, URL).
- `Atlas/Screens/Pricing/Resources/ExchangeRatesSnapshot.json`: ExchangeRate-API's
  rates per US dollar, with their date. The app refreshes them once a day at
  runtime (`ExchangeRateStore`); this file is what it starts from, and what it
  uses offline.

`PriceIndexSnapshot-Sample.json` is the design prototype's sample (approximate)
for DEBUG scenes and tests. The script never touches it.

## Before each release

```sh
python3 -I scripts/price-index/fetch_price_index.py --check   # download and check only
python3 -I scripts/price-index/fetch_price_index.py           # write both files
git diff --stat Atlas/Screens/Pricing/Resources
```

Python 3 standard library only; no keys, nothing personal is sent. `--index` or
`--rates` writes one file.

The script exits non-zero and writes nothing when a check fails: a value that is
not positive or finite, outside 0.08–3.0, the United States not 1, too few
territories (World Bank and IMF 140, Big Mac 45), too few distinct values, a
currency an App Store territory uses without a rate, or a move over 35% against
the previous published file. Read the moves it prints; when they are real (a
devaluation, a new edition), rerun with `--accept-moves`.

Then run the unit tests: `PriceIndexEditionTextTests` checks that every edition
text matches the pattern Atlas translates (`PriceIndexEditionText.generated`),
and `BundledPriceIndexSnapshotTests` checks the file as the app reads it.

## The chain per territory

- **World Bank.** `PA.NUS.PPPC.RF` moved to the WDI Database Archives (source 57);
  its last archived figures (February 2026 version) stop at 2024. Current WDI
  still publishes the two series it is made of, `PA.NUS.PPP` and
  `PA.NUS.FCRF`, a year newer. **Exact** is PPP ÷ FCRF of the edition's data
  year (the newest year at least 100 countries have). **Fallback** is the
  archived `PPPC.RF` or PPP ÷ FCRF of up to two years earlier. Aggregates
  (regions, income groups) are left out.
- **IMF.** `PPPEX` (World Economic Outlook) includes projections to 2031; the
  year used is the edition's year − 1, the last one that isn't a projection.
  **Exact** is PPPEX ÷ World Bank FCRF of that year; **fallback** is NGDPD ÷
  PPPGDP (the same ratio through the IMF's own rates), e.g. for Taiwan.
- **Big Mac.** The Economist's `big-mac-full-index.csv`, latest date: dollar
  price ÷ US dollar price. The euro area is one shared entry.
- Any derived value more than 1.5× away from the IMF's unit-free NGDPD ÷ PPPGDP
  mixes currencies (Bulgaria's 2025 PPP is already in euros, its rate still in
  leva) and is left out, so the next value in the chain is used.

In the app, a territory without a value in the chosen index takes the next
index in the strategy's fallback chain, then the region median, then Apple's
equalized price. Fallback values show the Fallback pill in the Source column.

## Why the index isn't refreshed at runtime

Publishers update once or twice a year (World Bank once, IMF in April and
October, Big Mac in January and July), and each new edition needs these checks
and a look at its moves. So the index is bundled per release; exchange rates,
which change daily, refresh at runtime.

Sources: World Bank WDI (CC BY 4.0), IMF DataMapper, The Economist's
big-mac-data (MIT), ExchangeRate-API open access ("Rates by ExchangeRate-API").
