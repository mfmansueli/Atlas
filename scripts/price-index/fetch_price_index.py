#!/usr/bin/env python3
"""Downloads the price indices and exchange rates Atlas ships with, checks
them, and writes the bundled snapshots.

    python3 -I scripts/price-index/fetch_price_index.py            # both files
    python3 -I scripts/price-index/fetch_price_index.py --index    # index only
    python3 -I scripts/price-index/fetch_price_index.py --rates    # rates only
    python3 -I scripts/price-index/fetch_price_index.py --check    # validate, write nothing

Standard library only. Exits non-zero when a check fails, so a release can't
ship a broken snapshot. See README.md next to this file.

Sources and the chain per territory (each value keeps its year and method):

World Bank. PA.NUS.PPPC.RF (price level ratio) was moved to the "WDI Database
Archives" (source 57); its newest archived figures (Feb 2026 version) stop at
2024. Current WDI still publishes the two series it is made of, PA.NUS.PPP
(PPP conversion factor, GDP) and PA.NUS.FCRF (official exchange rate, period
average), one year newer. PPP / FCRF of the same year *is* the price level
ratio's definition, so:
  exact    = PPP / FCRF of the edition's data year (the newest year most
             countries have);
  fallback = the archived PPPC.RF, or PPP / FCRF, of an older year (at most
             two years older), whichever is newest.
IMF. PPPEX (implied PPP conversion rate, WEO) includes projections up to 2031.
The year used is the edition year - 1 (the last year that is not a
projection for nearly every country: October 2026 WEO -> 2025).
  exact    = PPPEX / World Bank FCRF of that year;
  fallback = NGDPD / PPPGDP of that year (the same ratio through the IMF's own
             exchange rates), for territories the World Bank has no rate for
             (Taiwan, for one).
Big Mac. The Economist's big-mac-full-index.csv, latest date. Level = local
dollar price / US dollar price. The euro area is one shared entry.
Exchange rates. open.er-api.com (ExchangeRate-API, open access, keyless, daily;
attribution "Rates by ExchangeRate-API").
"""

import argparse
import csv
import datetime as dt
import io
import json
import math
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
TABLE = os.path.join(ROOT, "Atlas", "Models", "Territories", "TerritoryCatalog+Table.swift")
RESOURCES = os.path.join(ROOT, "Atlas", "Screens", "Pricing", "Resources")
INDEX_OUT = os.path.join(RESOURCES, "PriceIndexSnapshot.json")
RATES_OUT = os.path.join(RESOURCES, "ExchangeRatesSnapshot.json")

WB = "https://api.worldbank.org/v2"
WB_ARCHIVE = 57
IMF = "https://www.imf.org/external/datamapper/api/v1"
BIG_MAC_CSV = "https://raw.githubusercontent.com/TheEconomist/big-mac-data/master/output-data/big-mac-full-index.csv"
RATES_URL = "https://open.er-api.com/v6/latest/USD"

# Publisher codes that differ from App Store Connect's territory IDs.
ALIASES = {"XKX": "XKS", "UVK": "XKS", "KSV": "XKS"}

# Euro area members in 2026 (Bulgaria joined on 1 January 2026), for the Big
# Mac Index's single euro-area entry.
EURO_AREA = [
    "AUT", "BEL", "BGR", "HRV", "CYP", "EST", "FIN", "FRA", "DEU", "GRC", "IRL",
    "ITA", "LVA", "LTU", "LUX", "MLT", "NLD", "PRT", "SVK", "SVN", "ESP",
]

# Checks.
PLAUSIBLE = (0.08, 3.0)
MIN_COVERAGE = {"worldBank": 140, "imf": 140, "bigMac": 45}
MIN_DISTINCT_SHARE = 0.8
BIG_MOVE = 0.35
# A derived value further than this factor from the IMF's unit-free ratio
# (NGDPD / PPPGDP) mixes currencies, e.g. Bulgaria's 2025 PPP already in euros
# while its exchange rate is still in leva. Such values are left out.
UNIT_MISMATCH = 1.5
MONTHS = ["January", "February", "March", "April", "May", "June", "July",
          "August", "September", "October", "November", "December"]


class CheckFailed(Exception):
    pass


def fetch(url, timeout=90):
    # Python's own User-Agent: the IMF's API refuses unknown ones.
    with urllib.request.urlopen(url, timeout=timeout) as response:
        return response.read()


def fetch_json(url, timeout=90):
    return json.loads(fetch(url, timeout).decode("utf-8"))


def territories():
    """Atlas's 175 territories: alpha-3 -> (alpha-2, name, currency)."""
    with open(TABLE, encoding="utf-8") as handle:
        text = handle.read()
    rows = {}
    for line in text.splitlines():
        parts = line.strip().split("|")
        if len(parts) == 8 and re.fullmatch(r"[A-Z]{3}", parts[0]):
            rows[parts[0]] = {"alpha2": parts[1], "name": parts[2], "currency": parts[4]}
    if len(rows) != 175:
        raise CheckFailed(f"TerritoryCatalog+Table.swift has {len(rows)} territories, expected 175")
    return rows


def territory_id(code, known):
    code = ALIASES.get(code, code)
    return code if code in known else None


def short_month(date):
    return MONTHS[date.month - 1][:3]


# MARK: - World Bank


def wb_countries():
    """ISO3 codes that are countries, not aggregates (regions, income groups)."""
    data = fetch_json(f"{WB}/country?format=json&per_page=400")
    return {row["id"] for row in data[1] if row["region"]["id"] != "NA"}


def wb_series(indicator, first_year, last_year):
    data = fetch_json(f"{WB}/country/all/indicator/{indicator}?format=json&per_page=20000&date={first_year}:{last_year}")
    header, rows = data[0], data[1] or []
    values = {}
    for row in rows:
        if row["value"] is None:
            continue
        values.setdefault(row["countryiso3code"], {})[int(row["date"])] = float(row["value"])
    return values, header.get("lastupdated")


def wb_archive_pppc(first_year, last_year):
    """The archived price level ratio from the newest archive version with data."""
    versions = fetch_json(f"{WB}/sources/{WB_ARCHIVE}/version?format=json&per_page=500")
    ids = [item["id"] for item in versions["source"][0]["concept"][0]["variable"]]
    years = ";".join(f"YR{year}" for year in range(first_year, last_year + 1))
    for version in reversed(ids[-12:]):
        # Probe one country first: newer versions keep the series with no values.
        probe = f"{WB}/sources/{WB_ARCHIVE}/country/USA/series/PA.NUS.PPPC.RF/version/{version}/time/{years}?format=json"
        try:
            rows = fetch_json(probe, timeout=60).get("source", {}).get("data", [])
        except Exception as error:  # noqa: BLE001 - the archive is a fallback only
            print(f"  archive version {version}: {error}", file=sys.stderr)
            continue
        if not any(row["value"] is not None for row in rows):
            continue
        url = (f"{WB}/sources/{WB_ARCHIVE}/country/all/series/PA.NUS.PPPC.RF/version/{version}/time/{years}"
               "?format=json&per_page=5000")
        try:
            data = fetch_json(url, timeout=120)
        except Exception as error:  # noqa: BLE001 - the archive is a fallback only
            print(f"  archive version {version}: {error}", file=sys.stderr)
            continue
        values = {}
        for item in data.get("source", {}).get("data", []):
            if item["value"] is None:
                continue
            variables = {v["concept"]: v["id"] for v in item["variable"]}
            values.setdefault(variables["Country"], {})[int(variables["Time"][2:])] = float(item["value"])
        if values:
            return values, version
    return {}, None


def mismatched(value, reference):
    return reference is not None and max(value / reference, reference / value) > UNIT_MISMATCH


def world_bank(known, today, imf_ratio, notes):
    countries = wb_countries()
    first, last = today.year - 5, today.year
    ppp, updated = wb_series("PA.NUS.PPP", first, last)
    fcrf, _ = wb_series("PA.NUS.FCRF", first, last)
    archive, archive_version = wb_archive_pppc(first, last)

    def derived(code, year):
        p, f = ppp.get(code, {}).get(year), fcrf.get(code, {}).get(year)
        return p / f if p and f and f > 0 else None

    # The edition's data year: the newest year most countries have.
    counts = {}
    for code in countries:
        for year in ppp.get(code, {}):
            if derived(code, year) is not None:
                counts[year] = counts.get(year, 0) + 1
    data_year = max(year for year, count in counts.items() if count >= 100)

    levels = {}
    for code in sorted(countries):
        tid = territory_id(code, known)
        if not tid:
            continue
        value = derived(code, data_year)
        if value is not None and not mismatched(value, imf_ratio(code, data_year)):
            levels[tid] = (value, data_year, "exact")
            continue
        if value is not None:
            notes.append(f"worldBank: {tid} PPP / FCRF {data_year} = {value:.3f} mixes currencies, left out")
        candidates = []
        for year in range(data_year - 1, data_year - 3, -1):
            if archive.get(code, {}).get(year):
                candidates.append((year, 1, archive[code][year]))
            older = derived(code, year)
            if older is not None and not mismatched(older, imf_ratio(code, year)):
                candidates.append((year, 0, older))
        if candidates:
            year, _, value = max(candidates)
            levels[tid] = (value, year, "fallback")

    published = dt.date.fromisoformat(updated) if updated else today
    edition = {
        "label": f"{data_year} data, published {published.year}",
        "badge": f"WB {data_year}",
        "provenanceLabel": f"World Bank {data_year}",
        "date": published.isoformat(),
        "fetched": today.isoformat(),
        "dataYear": data_year,
        "url": "https://data.worldbank.org/indicator/PA.NUS.PPP",
        "method": f"PA.NUS.PPP / PA.NUS.FCRF, {data_year} (WDI {published.isoformat()}); "
                  f"older years from the archived PA.NUS.PPPC.RF (version {archive_version})",
    }
    return edition, levels, fcrf


# MARK: - IMF


def imf_series(indicator):
    return fetch_json(f"{IMF}/{indicator}")["values"][indicator]


class ImfRatio:
    """NGDPD / PPPGDP: the IMF's price level through its own exchange rates,
    free of currency units, so it also cross-checks derived values."""

    def __init__(self):
        self.usd = imf_series("NGDPD")
        self.ppp = imf_series("PPPGDP")

    def __call__(self, code, year):
        usd = self.usd.get(code, {}).get(str(year))
        ppp = self.ppp.get(code, {}).get(str(year))
        if usd is None and code in ALIASES.values():
            for alias, target in ALIASES.items():
                if target == code and alias in self.usd:
                    return self(alias, year)
        return usd / ppp if usd and ppp else None


def imf(known, today, fcrf, imf_ratio, notes):
    meta = fetch_json(f"{IMF}/indicators")["indicators"]["PPPEX"]
    match = re.search(r"\((\w+) (\d{4})\)", meta.get("source", ""))
    if not match:
        raise CheckFailed(f"IMF: no edition in {meta.get('source')!r}")
    month, edition_year = match.group(1), int(match.group(2))
    data_year = edition_year - 1
    modified = dt.date.fromisoformat(meta.get("last-modified", today.isoformat())[:10])
    pppex = imf_series("PPPEX")
    levels = {}
    for code, series in pppex.items():
        tid = territory_id(code, known)
        if not tid:
            continue
        rate = series.get(str(data_year))
        market = fcrf.get(code, {}).get(data_year) or fcrf.get(ALIASES.get(code, code), {}).get(data_year)
        ratio = imf_ratio(code, data_year)
        if rate and market and not mismatched(rate / market, ratio):
            levels[tid] = (rate / market, data_year, "exact")
            continue
        if rate and market:
            notes.append(f"imf: {tid} PPPEX / FCRF {data_year} = {rate / market:.3f} mixes currencies, NGDPD / PPPGDP used")
        if ratio:
            levels[tid] = (ratio, data_year, "fallback")
    edition = {
        "label": f"{month} {edition_year} WEO",
        "badge": f"IMF {month[:3]} {str(edition_year)[2:]}",
        "provenanceLabel": f"IMF, {month[:3]} {edition_year}",
        "date": modified.isoformat(),
        "fetched": today.isoformat(),
        "dataYear": data_year,
        "url": "https://www.imf.org/external/datamapper/PPPEX@WEO",
        "method": f"PPPEX / World Bank PA.NUS.FCRF, {data_year}; else NGDPD / PPPGDP, {data_year} "
                  f"(World Economic Outlook, {month} {edition_year}; later years are projections)",
    }
    return edition, levels


# MARK: - Big Mac


def big_mac(known, today):
    rows = list(csv.DictReader(io.StringIO(fetch(BIG_MAC_CSV).decode("utf-8"))))
    latest = max(row["date"] for row in rows)
    rows = [row for row in rows if row["date"] == latest]
    us = next(float(row["dollar_price"]) for row in rows if row["iso_a3"] == "USA")
    date = dt.date.fromisoformat(latest)
    levels, shared = {}, None
    for row in rows:
        price = float(row["dollar_price"])
        if row["iso_a3"] == "EUZ":
            shared = price / us
            continue
        tid = territory_id(row["iso_a3"], known)
        if tid:
            levels[tid] = (price / us, date.year, "exact")
    shared_entries = []
    if shared is not None:
        members = [tid for tid in EURO_AREA if tid in known and tid not in levels]
        shared_entries.append({"name": "Euro area", "level": shared, "year": date.year, "method": "exact", "territories": members})
    edition = {
        "label": f"{MONTHS[date.month - 1]} {date.year}",
        "badge": f"Big Mac {short_month(date)} {str(date.year)[2:]}",
        "provenanceLabel": f"Big Mac, {short_month(date)} {date.year}",
        "date": latest,
        "fetched": today.isoformat(),
        "dataYear": date.year,
        "url": "https://www.economist.com/big-mac-index",
        "method": "dollar_price / US dollar_price, raw index (big-mac-full-index.csv)",
    }
    return edition, levels, shared_entries


# MARK: - Checks


def rounded(value):
    return float(f"{value:.4g}") if value < 1 else round(value, 3)


def check_source(key, levels, shared, problems, notes):
    values = {tid: level for tid, (level, _, _) in levels.items()}
    for entry in shared:
        for tid in entry["territories"]:
            values[tid] = entry["level"]
    if not values:
        problems.append(f"{key}: no values")
        return
    for tid, level in values.items():
        if not math.isfinite(level) or level <= 0:
            problems.append(f"{key}: {tid} is {level}")
        elif not PLAUSIBLE[0] <= level <= PLAUSIBLE[1]:
            problems.append(f"{key}: {tid} = {level:.3f} is outside {PLAUSIBLE}")
    if "USA" not in values or abs(values["USA"] - 1) > 1e-6:
        problems.append(f"{key}: USA is {values.get('USA')}, not 1")
    if len(values) < MIN_COVERAGE[key]:
        problems.append(f"{key}: {len(values)} territories, expected at least {MIN_COVERAGE[key]}")
    distinct = len({rounded(level) for level in levels.values() for level in [level[0]]})
    if distinct < MIN_DISTINCT_SHARE * len(levels):
        problems.append(f"{key}: only {distinct} distinct values for {len(levels)} territories")
    fallback = sum(1 for _, _, method in levels.values() if method == "fallback")
    notes.append(f"{key}: {len(values)} territories, {distinct} distinct values, {fallback} fallback")


def previous_levels(path):
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError):
        return None, {}
    result = {}
    for key, source in data.get("sources", {}).items():
        values = {}
        for tid, entry in (source.get("levels") or {}).items():
            values[tid] = entry["level"]
        for tid, factor in (source.get("factors") or {}).items():
            values[tid] = factor
        for entry in source.get("shared") or []:
            for tid in entry["territories"]:
                values[tid] = entry.get("level", entry.get("factor"))
        result[key] = values
    return data.get("approximate", True), result


def report_moves(key, levels, shared, previous, approximate, problems, notes):
    before = previous.get(key) or {}
    now = {tid: level for tid, (level, _, _) in levels.items()}
    for entry in shared:
        for tid in entry["territories"]:
            now[tid] = entry["level"]
    moves = sorted(
        ((abs(now[tid] / before[tid] - 1), tid, before[tid], now[tid]) for tid in now if before.get(tid)),
        reverse=True,
    )
    lines = ", ".join(f"{tid} {old:.2f}->{new:.2f}" for _, tid, old, new in moves[:8])
    notes.append(f"{key}: biggest moves vs previous file: {lines or 'none'}")
    if not approximate:
        for move, tid, old, new in moves:
            if move > BIG_MOVE:
                problems.append(f"{key}: {tid} moved {old:.3f} -> {new:.3f} ({move:.0%}); rerun with --accept-moves if real")


# MARK: - Writing


def source_json(edition, levels, shared):
    out = {"edition": edition, "levels": {}}
    for tid in sorted(levels):
        level, year, method = levels[tid]
        out["levels"][tid] = {"level": rounded(level), "year": year, "method": method}
    if shared:
        out["shared"] = [dict(entry, level=rounded(entry["level"])) for entry in shared]
    return out


def build_index(known, today, args):
    problems, notes = [], []
    print("IMF ratios…", file=sys.stderr)
    imf_ratio = ImfRatio()
    print("World Bank…", file=sys.stderr)
    wb_edition, wb_levels, fcrf = world_bank(known, today, imf_ratio, notes)
    print("IMF…", file=sys.stderr)
    imf_edition, imf_levels = imf(known, today, fcrf, imf_ratio, notes)
    print("Big Mac…", file=sys.stderr)
    bm_edition, bm_levels, bm_shared = big_mac(known, today)
    sources = {
        "bigMac": (bm_edition, bm_levels, bm_shared),
        "worldBank": (wb_edition, wb_levels, []),
        "imf": (imf_edition, imf_levels, []),
    }
    approximate, previous = previous_levels(INDEX_OUT)
    for key, (_, levels, shared) in sources.items():
        check_source(key, levels, shared, problems, notes)
        report_moves(key, levels, shared, previous, approximate or args.accept_moves, problems, notes)
    snapshot = {
        "schema": 2,
        "approximate": False,
        "note": ("Published figures: World Bank WDI, IMF World Economic Outlook and The Economist's Big Mac Index. "
                 "Each level is the territory's price level relative to the United States (1.0). Generated by "
                 "scripts/price-index/fetch_price_index.py."),
        "snapshotDate": today.isoformat(),
        "referenceTerritory": "USA",
        "sources": {key: source_json(*value) for key, value in sources.items()},
    }
    return snapshot, problems, notes


def build_rates(known, today):
    data = fetch_json(RATES_URL)
    problems, notes = [], []
    if data.get("result") != "success" or data.get("base_code") != "USD":
        problems.append(f"rates: unexpected answer {data.get('result')!r} base {data.get('base_code')!r}")
    rates = {code: float(rate) for code, rate in (data.get("rates") or {}).items()}
    if abs(rates.get("USD", 0) - 1) > 1e-9:
        problems.append("rates: USD is not 1")
    for code, rate in rates.items():
        if not math.isfinite(rate) or rate <= 0:
            problems.append(f"rates: {code} is {rate}")
    needed = sorted({row["currency"] for row in known.values()})
    missing = [code for code in needed if code not in rates]
    if missing:
        problems.append(f"rates: no rate for {', '.join(missing)}")
    published = dt.datetime.fromtimestamp(int(data.get("time_last_update_unix", 0)), dt.timezone.utc)
    notes.append(f"rates: {len(rates)} currencies, published {published.isoformat()}, {len(needed)} needed by territories")
    snapshot = {
        "source": "exchangeRateAPI",
        "date": published.date().isoformat(),
        "fetched": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "base": "USD",
        "rates": {code: rates[code] for code in sorted(rates)},
    }
    return snapshot, problems, notes


def write(path, snapshot):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(snapshot, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    print(f"wrote {os.path.relpath(path, ROOT)}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--index", action="store_true", help="only the price index snapshot")
    parser.add_argument("--rates", action="store_true", help="only the exchange rates snapshot")
    parser.add_argument("--check", action="store_true", help="download and check, write nothing")
    parser.add_argument("--accept-moves", action="store_true", help="allow moves over 35%% against the previous file")
    args = parser.parse_args()
    both = not args.index and not args.rates
    today = dt.date.today()
    try:
        known = territories()
        outputs, problems, notes = [], [], []
        if both or args.index:
            snapshot, found, said = build_index(known, today, args)
            outputs.append((INDEX_OUT, snapshot))
            problems += found
            notes += said
        if both or args.rates:
            snapshot, found, said = build_rates(known, today)
            outputs.append((RATES_OUT, snapshot))
            problems += found
            notes += said
    except CheckFailed as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    except Exception as error:  # noqa: BLE001 - any download or format failure stops the release
        print(f"error: {type(error).__name__}: {error}", file=sys.stderr)
        return 1
    for note in notes:
        print(note)
    if problems:
        print("\nChecks failed, nothing written:", file=sys.stderr)
        for problem in problems:
            print(f"  - {problem}", file=sys.stderr)
        return 1
    if not args.check:
        for path, snapshot in outputs:
            write(path, snapshot)
    return 0


if __name__ == "__main__":
    sys.exit(main())
