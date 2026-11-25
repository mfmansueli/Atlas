//
//  MCPPriceTrustReader.swift
//  Atlas
//

import Foundation

/// What get_prices says each price stands on (the Pricing trust work):
/// per territory how sure Atlas is and why, the sales behind it (90 and
/// 28 days, and the region a thin country borrows from), the index value
/// with its edition and trust, the exchange rate, and whether Apple's own
/// price points were read; per product the sales state with the banner's
/// line, the traffic-weighted how sure and the count of suggestions.
@MainActor
struct MCPPriceTrustReader {
    let sheet: MCPPriceSheet
    let include: Set<MCPPriceInclude>
    let pooling: ConversionPooling
    let rates: ExchangeRates
    /// When Apple's points were read, by territory.
    let readDates: [String: Date]
    var asOf = Date.now

    init(sheet: MCPPriceSheet, include: Set<MCPPriceInclude> = MCPPriceInclude.defaults, rates: ExchangeRates = .current) {
        self.sheet = sheet
        self.include = include
        self.rates = rates
        pooling = sheet.pooling
        readDates = sheet.workspace.services.pricing.ladderReadDates(for: sheet.product.id, commission: sheet.calculator.commission)
    }

    // MARK: - Territory

    /// The territory's fields, added to its get_prices entry.
    func fields(for row: PricingRow) -> [String: JSONValue] {
        var fields: [String: JSONValue] = [:]
        let confidence = include.contains(.howSure) || include.contains(.evidence) ? sheet.confidence(of: row, pooling: pooling) : nil
        if include.contains(.howSure), let confidence { fields["howSure"] = MCPPriceTrustJSON.howSure(confidence) }
        if include.contains(.evidence), let evidence = evidence(for: row.territory, borrowedFrom: confidence?.borrowedFrom) {
            fields["evidence"] = evidence
        }
        if include.contains(.index) { fields["index"] = index(for: row) }
        if include.contains(.exchangeRate), let rate = rates.unitsPerDollar[row.territory.currencyCode.uppercased()] {
            fields["exchangeRate"] = ["currency": .string(row.territory.currencyCode), "perDollar": .double(rate.doubleValue)]
        }
        if include.contains(.grid) { fields["grid"] = grid(for: row) }
        return fields
    }

    /// The sales Atlas reads there; nil when it reads none.
    func evidence(for territory: Territory, borrowedFrom: TerritoryRegion?) -> JSONValue? {
        let sales = sheet.sheet.sales
        guard sales.canRead else { return nil }
        var object: [String: JSONValue] = [:]
        if let signal = sales.signals[territory.id] { object["days90"] = MCPPriceTrustJSON.signal(signal) }
        if let signal = sales.recentSignals[territory.id] { object["days28"] = MCPPriceTrustJSON.signal(signal) }
        if let borrowedFrom, let pooled = pooling.estimate(for: territory.id) {
            object["borrowedFrom"] = [
                "region": .string(borrowedFrom.rawValue),
                "name": .string(borrowedFrom.title),
                "days90": MCPPriceTrustJSON.signal(pooled.regionTotal),
            ]
        }
        if let prior = sales.priorChanges[territory.id] {
            object["earlierChange"] = [
                "date": .string(MCPPriceTrustJSON.day(prior.date)),
                "previousPrice": MCPPriceValue.json(prior.previousPrice),
                "before28": MCPPriceTrustJSON.signal(prior.before),
                "after28": MCPPriceTrustJSON.signal(prior.after),
            ]
        }
        return object.isEmpty ? nil : .object(object)
    }

    /// The purchasing-power value behind the suggestion (the app's own
    /// strategy's, without one).
    func index(for row: PricingRow) -> JSONValue {
        let provenance = row.recommendation?.calculation?.provenance ?? row.calculation.provenance
        let factor = row.recommendation?.factor ?? row.calculation.factor
        let recommender = PriceRecommender(calculator: sheet.calculator, baseTerritoryID: sheet.sheet.baseTerritoryID, asOf: asOf)
        let trust = recommender.indexTrust(territoryID: row.territory.id, provenance: provenance).trust
        var object: [String: JSONValue] = [
            "basis": .string(MCPPriceTrustJSON.basis(provenance.kind)),
            "label": .string(provenance.label),
            "trust": .string(MCPPriceTrustJSON.trust(trust)),
            "factor": .double(factor.rounded(scale: 4).doubleValue),
        ]
        if let source = provenance.source { object["source"] = .string(source.rawValue) }
        if let edition = provenance.edition { object["edition"] = .string(edition.label) }
        if let year = provenance.level?.year ?? provenance.edition?.dataYear { object["dataYear"] = .int(year) }
        if let level = provenance.level { object["method"] = .string(level.method.rawValue) }
        return .object(object)
    }

    /// Whether Apple's own points are here, when they were read, and the
    /// suggested point's price and proceeds.
    func grid(for row: PricingRow) -> JSONValue {
        var object: [String: JSONValue] = ["real": .bool(sheet.sheet.hasRealGrid(row.territory.id))]
        if let date = readDates[row.territory.id] { object["readAt"] = .string(date.formatted(.iso8601)) }
        if let point = row.recommendation?.price, PricingRow.differs(point.customerPrice, row.current.customerPrice) {
            var suggested: [String: JSONValue] = [
                "customerPrice": MCPPriceValue.json(point.customerPrice),
                "proceeds": MCPPriceValue.json(point.proceeds.rounded(scale: 2)),
            ]
            if let pointID = point.appStoreConnectID { suggested["pricePointId"] = .string(pointID) }
            object["suggestedPoint"] = .object(suggested)
        }
        return .object(object)
    }

    // MARK: - Product

    /// The product's `trust`: the sales state and its line, the
    /// traffic-weighted how sure of the open suggestions, how many there
    /// are, and with none the summary line Prices by Country shows.
    func product(countries: [CountryPriceRow], rows: [PricingRow]) -> JSONValue {
        let sales = sheet.sheet.sales
        let suggested = countries.filter(\.hasSuggestion)
        let salesCountries = sales.signals.values.count { $0.starts > 0 }
        let borrowed = suggested.count { $0.evidence?.borrowedFrom != nil }
        var salesObject: [String: JSONValue] = [
            "availability": .string(MCPPriceTrustJSON.availability(sales.availability)),
            "line": .string(PricingSalesLine.banner(availability: sales.availability, salesCountries: salesCountries, borrowedCountries: borrowed)),
        ]
        if let readThrough = sales.readThrough { salesObject["readThrough"] = .string(MCPPriceTrustJSON.day(readThrough)) }
        var object: [String: JSONValue] = ["sales": .object(salesObject), "suggestions": .int(suggested.count)]
        if !suggested.isEmpty {
            let level = HowSureWeighting.level(suggested.map { row in
                HowSureWeighting.Entry(level: row.confidence?.howSure ?? .notVerySure, pageViews: row.pageViews ?? 0)
            })
            object["howSure"] = MCPPriceTrustJSON.howSure(level)
        } else if sheet.showsSuggestions, !countries.contains(where: { $0.suggested != nil }),
                  let line = PricesByCountryMatchLine.text(count: rows.count { !$0.isBase && $0.recommendation?.isUnchanged == true })
        {
            object["matchLine"] = .string(line)
        }
        return .object(object)
    }
}
