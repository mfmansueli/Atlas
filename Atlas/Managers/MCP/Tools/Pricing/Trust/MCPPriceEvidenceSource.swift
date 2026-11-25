//
//  MCPPriceEvidenceSource.swift
//  Atlas
//

import Foundation

/// Where an assistant's price came from, as propose_prices' `evidence`
/// names it.
enum MCPPriceEvidenceSource: String, CaseIterable, Hashable, Sendable {
    /// App Analytics: page views, downloads.
    case analytics
    /// Sales and Trends: trial and paid starts, proceeds.
    case sales
    /// Purchasing power: World Bank, IMF or the Big Mac Index.
    case priceIndex
    case exchangeRates
    /// The app's own code: a StoreKit file, the paywall, a price constant.
    /// The price then mirrors the project's, so Atlas's sales don't cap
    /// how sure it is.
    case project
    /// Anything else: a competitor's price, a published report.
    case outside

    /// How the details line names it: "Analytics · Brazil, 28 days: …".
    var title: String {
        switch self {
        case .analytics: String(localized: "Analytics", comment: "kind:label")
        case .sales: String(localized: "Sales", comment: "kind:label")
        case .priceIndex: String(localized: "Purchasing power", comment: "kind:label")
        case .exchangeRates: String(localized: "Exchange rates", comment: "kind:label")
        case .project: String(localized: "Project", comment: "kind:label")
        case .outside: String(localized: "Outside source", comment: "kind:label")
        }
    }

    /// Reads Atlas's sales, so Atlas must read them too for the person to
    /// check it.
    var needsSales: Bool { self == .analytics || self == .sales }

    /// The source as written, case, spaces and a few other names allowed:
    /// "App Analytics", "salesAndTrends", "World Bank", "StoreKit", "web".
    static func parse(_ text: String) -> Self? {
        let key = text.lowercased().filter(\.isLetter)
        if let source = allCases.first(where: { $0.rawValue.lowercased() == key }) { return source }
        switch key {
        case "appanalytics", "pageviews", "downloads": return .analytics
        case "salesandtrends", "trials", "proceeds": return .sales
        case "index", "purchasingpower", "worldbank", "imf", "bigmac", "ppp": return .priceIndex
        case "exchangerate", "rates", "fx": return .exchangeRates
        case "code", "storekit", "paywall", "file": return .project
        case "web", "competitor", "report", "other": return .outside
        default: return nil
        }
    }
}
