//
//  AnalyticsMCPBreakdown.swift
//  Atlas
//

import Foundation

/// The `by` argument of the newer reports' tools (README-An2: each takes
/// the app, the period and what to break it down by): one of Apple's report
/// columns, from the choices each tool has.
enum AnalyticsMCPBreakdown {
    /// `by`'s values and the report column each reads.
    static let dimensions: [String: ReportDimension] = [
        "productPage": .page, "campaign": .campaign, "source": .source, "territory": .territory, "device": .device,
        "appVersion": .appVersion, "subscription": .subscription, "offer": .offerName, "messageType": .messageType,
    ]

    /// What each value means, for the tools' descriptions.
    private static let meanings: [String: String] = [
        "productPage": "productPage (the product page or In-App Event people came through)",
        "campaign": "campaign (a campaign link's ct token)",
        "source": "source (App Store Search, Browse, App Referrer, Web Referrer…)",
        "territory": "territory (alpha-2)",
        "device": "device",
        "appVersion": "appVersion",
        "subscription": "subscription",
        "offer": "offer (by name)",
        "messageType": "messageType (Apple's retention message type)",
    ]

    /// The `by` argument, one of `allowed`; nil when it's left out.
    static func dimension(_ arguments: MCPToolArguments, allowed: [String]) throws -> (name: String, dimension: ReportDimension)? {
        guard let name = try arguments.optionalString("by") else { return nil }
        guard allowed.contains(name), let dimension = dimensions[name] else {
            throw MCPToolError.invalidArgument(name: "by", expected: list(allowed))
        }
        return (name, dimension)
    }

    /// The schema entry for `by`, with `allowed`'s meanings.
    static func schema(_ allowed: [String], leftOut: String) -> JSONValue {
        let choices = allowed.map { meanings[$0] ?? $0 }
        return MCPToolDefinition.string("What to break it down by: \(list(choices)). \(leftOut)")
    }

    /// A record's value in `dimension`: a product page by the name Apple's
    /// reports give it, the default page included.
    static func key(_ record: ReportRecord, _ dimension: ReportDimension) -> String {
        dimension == .page ? ReportsArchive.pageName(record, defaultName: ProductPageNumbers.defaultPageName) ?? "" : record[dimension]
    }

    /// The values `records` have in `dimension`, sorted, empty ones left out.
    static func names(_ records: [ReportRecord], _ dimension: ReportDimension) -> [String] {
        Set(records.map { key($0, dimension) }).filter { !$0.isEmpty }.sorted()
    }

    /// "territory, device or offer".
    static func list(_ names: [String]) -> String {
        guard let last = names.last else { return "" }
        return names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " or " + last
    }
}
