//
//  MCPPriceEvidence.swift
//  Atlas
//

import Foundation

/// One thing an assistant based a price on (propose_prices' `evidence`):
/// its source and one short line with the number that decides it, e.g.
/// `{source: "analytics", detail: "Brazil, 28 days: 1,240 page views"}`.
/// Checked like the card texts before anything is queued, then written on
/// the change as its details ("Based on: …"), never shown as sent.
struct MCPPriceEvidence: Hashable, Sendable {
    /// A detail is one short line, like a pill's label.
    static let detailLimit = 60
    /// At most this many, so the details line stays within its limit.
    static let itemLimit = 4
    /// What Atlas never writes (README-DS §9), so an assistant's line
    /// doesn't either.
    static let bannedWords: Set<String> = [
        "simply", "just", "easily", "seamlessly", "powerful", "leverage", "magic", "please", "oops", "successfully",
    ]

    var source: MCPPriceEvidenceSource
    var detail: String

    // MARK: - Schema

    static let itemSchema: JSONValue = MCPToolDefinition.schema(
        [
            "source": [
                "type": "string",
                "enum": .array(MCPPriceEvidenceSource.allCases.map { .string($0.rawValue) }),
                "description": """
                analytics (page views, downloads) or sales (trials, paid starts, proceeds) as get_prices' evidence has them, \
                priceIndex, exchangeRates, project (the app's code: a StoreKit file, the paywall, a price constant) or \
                outside (a competitor's price, a report).
                """,
            ],
            "detail": MCPToolDefinition.string("""
            One line, at most \(detailLimit) characters, with the number that decides it: “Brazil, 28 days: 31 trials”, \
            “Products.storekit:42 says $4.99”, “Spotify Brazil: R$ 21,90”.
            """),
        ],
        required: ["source", "detail"]
    )

    static let property: JSONValue = [
        "type": "array",
        "items": itemSchema,
        "description": .string("""
        Optional: what the price is based on, at most \(itemLimit), strongest first. Shown to the person as the change's \
        details. Evidence from project mirrors the app's own price, so its confidence isn't capped by Atlas's sales.
        """),
    ]

    // MARK: - Reading

    /// `evidence` as one object or a list; none when it's left out.
    static func read(_ value: JSONValue?) throws -> [MCPPriceEvidence] {
        guard let value, !value.isNull else { return [] }
        let expected = String(
            localized: "a list of {source, detail} objects, source one of analytics, sales, priceIndex, exchangeRates, project or outside",
            comment: "kind:other"
        )
        return try (value.arrayValue ?? [value]).map { item in
            guard let object = item.objectValue, let name = object["source"]?.stringValue, let source = MCPPriceEvidenceSource.parse(name) else {
                throw MCPToolError.invalidArgument(name: "evidence", expected: expected)
            }
            let detail = (object["detail"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return MCPPriceEvidence(source: source, detail: detail)
        }
    }

    /// The price mirrors the project's own: Atlas's sales don't cap it.
    static func mirrorsProject(_ evidence: [MCPPriceEvidence]) -> Bool {
        evidence.contains { $0.source == .project }
    }

    // MARK: - Checking

    /// What's wrong with it, each saying how to fix it; empty when it can
    /// be shown. `sales` is the product's, to check that sales evidence
    /// is something the person can see too; nil skips that check (a new
    /// subscription without prices).
    static func problems(_ evidence: [MCPPriceEvidence], sales: PricingSalesData?, productName: String) -> [String] {
        var problems: [String] = []
        if evidence.count > itemLimit {
            problems.append(String(localized: "Send at most \(itemLimit) evidence items, strongest first.", comment: "kind:other"))
        }
        for (index, item) in evidence.enumerated() {
            problems += textProblems(item.detail, field: "evidence[\(index)].detail")
        }
        if let sales, let source = evidence.first(where: \.source.needsSales)?.source,
           let problem = salesProblem(source, sales: sales, productName: productName)
        {
            problems.append(problem)
        }
        return problems
    }

    /// The detail's length and words.
    static func textProblems(_ text: String, field: String) -> [String] {
        guard !text.isEmpty else {
            return [String(localized: "\(field) is empty: say what you read, with its number, e.g. “Brazil, 28 days: 31 trials”.", comment: "kind:other")]
        }
        var problems: [String] = []
        if text.count > detailLimit {
            problems.append(String(
                localized: "\(field) is \(text.count) characters; at most \(detailLimit). Keep the number that decides it.",
                comment: "kind:other"
            ))
        }
        let words = Set(text.lowercased().split { !$0.isLetter }.map(String.init))
        if let word = bannedWords.sorted().first(where: words.contains) {
            problems.append(String(localized: "\(field) uses “\(word)”, which Atlas never writes. Say what you read plainly.", comment: "kind:other"))
        }
        if text.contains("!") {
            problems.append(String(localized: "\(field) has “!”, which Atlas never writes.", comment: "kind:other"))
        }
        return problems
    }

    /// Sales evidence the person can't check here: Atlas reads no sales,
    /// or there are none yet (page views still count as Analytics).
    private static func salesProblem(_ source: MCPPriceEvidenceSource, sales: PricingSalesData, productName: String) -> String? {
        if !sales.canRead {
            let line = PricingSalesLine.banner(availability: sales.availability, salesCountries: 0)
            return String(
                localized: "\(source.title) evidence can’t be checked here. \(line) Base it on priceIndex, exchangeRates, project or outside.",
                comment: "kind:other"
            )
        }
        guard source == .sales, sales.availability == .noSalesYet else { return nil }
        return String(
            localized: "\(productName) has no sales yet, so there are no trials or proceeds to cite. Use analytics page views, priceIndex, project or outside.",
            comment: "kind:other"
        )
    }

    // MARK: - Writing

    /// The change's details: "Based on: Analytics · Brazil, 28 days: 31
    /// trials; Project · Products.storekit:42 says $4.99"; nil without any.
    static func details(_ evidence: [MCPPriceEvidence]) -> String? {
        guard !evidence.isEmpty else { return nil }
        let list = evidence.map { "\($0.source.title) · \($0.detail)" }.joined(separator: "; ")
        return String(localized: "Based on: \(list)", comment: "kind:other")
    }
}
