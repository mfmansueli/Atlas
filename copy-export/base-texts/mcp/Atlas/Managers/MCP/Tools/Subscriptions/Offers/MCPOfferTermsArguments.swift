//
//  MCPOfferTermsArguments.swift
//  Atlas
//

import Foundation

/// The arguments `propose_promotional_offer`, `propose_win_back_offer` and
/// `propose_offer_code` share: an offer's mode, duration, periods, US
/// price, territories and territories priced apart, and the dates they
/// take as `yyyy-MM-dd`.
enum MCPOfferTermsArguments {
    /// The schema of the terms' arguments.
    static let properties: [String: JSONValue] = [
        "mode": [
            "type": "string",
            "enum": .array(OfferPaymentMode.allCases.map { .string($0.apiValue) }),
            "description": "FREE_TRIAL, PAY_AS_YOU_GO (a lower price each period) or PAY_UP_FRONT (one lower price for the whole duration).",
        ],
        "duration": [
            "type": "string",
            "enum": .array(IntroductoryOfferDuration.allCases.map { .string($0.rawValue) }),
            "description": .string("""
            How long it lasts; for PAY_AS_YOU_GO, how long one period is (the subscription's own). get_subscriptions' \
            offerDurations lists each mode's.
            """),
        ],
        "numberOfPeriods": ["type": "integer", "description": "PAY_AS_YOU_GO only: how many periods at the offer price."],
        "price": [
            "type": ["number", "string"],
            "description": .string("""
            Paid modes: the price in the United States in US dollars (per period for PAY_AS_YOU_GO), a price point from \
            get_price_points; equalized everywhere else.
            """),
        ],
        "territories": [
            "type": "array",
            "items": ["type": "string"],
            "description": "Optional territory codes, e.g. [\"USA\", \"BRA\"]; left out, every territory the subscription is sold in.",
        ],
        "territoryPrices": [
            "type": "object",
            "additionalProperties": ["type": ["number", "string"]],
            "description": .string("""
            Optional territories priced apart from the equalized price, in their own currency, e.g. {"BRA": 4.90}: each a \
            price point that territory has (get_price_points with territory).
            """),
        ],
    ]

    static let reasonProperties: [String: JSONValue] = [
        "reason": MCPToolDefinition.string("Why, in a sentence the person reads in Review & Push."),
        "evidence": [
            "type": "array",
            "items": ["type": "string"],
            "description": "What it's based on, e.g. Bruma/Paywall/WinBackView.swift:40 — offers “3 months at half price”.",
        ],
    ]

    /// The terms; throws for arguments that aren't usable at all.
    static func terms(from arguments: MCPToolArguments) throws -> OfferTerms {
        let modeText = try arguments.string("mode").uppercased()
        guard let mode = OfferPaymentMode(apiValue: modeText) else {
            throw MCPToolError.invalidArgument(name: "mode", expected: "FREE_TRIAL, PAY_AS_YOU_GO or PAY_UP_FRONT")
        }
        let durationText = try arguments.string("duration").uppercased()
        guard let duration = IntroductoryOfferDuration(rawValue: durationText) else {
            let names = IntroductoryOfferDuration.allCases.map(\.rawValue).joined(separator: ", ")
            throw MCPToolError.invalidArgument(name: "duration", expected: String(localized: "one of \(names)"))
        }
        var terms = try OfferTerms(mode: mode, duration: duration, numberOfPeriods: arguments.optionalInt("numberOfPeriods") ?? 1)
        if mode != .freeTrial {
            guard let value = arguments.values["price"], let price = MCPPriceValue.decimal(from: value) else {
                throw MCPToolError.invalidArgument(name: "price", expected: String(localized: "the offer's price in US dollars, e.g. 0.99"))
            }
            terms.price = price
        }
        try applyTerritories(from: arguments, to: &terms)
        return terms
    }

    /// `territories` and `territoryPrices` into `terms`.
    static func applyTerritories(from arguments: MCPToolArguments, to terms: inout OfferTerms) throws {
        if let territories = try arguments.optionalStrings("territories"), !territories.isEmpty {
            terms.territories = .chosen(territories.map { $0.trimmingCharacters(in: .whitespaces).uppercased() })
        }
        guard let object = try arguments.optionalObject("territoryPrices") else { return }
        var prices: [String: Decimal] = [:]
        for (territory, value) in object {
            guard let price = MCPPriceValue.decimal(from: value) else {
                let expected = String(localized: "{territory: price} with numbers, e.g. {\"BRA\": 4.90}")
                throw MCPToolError.invalidArgument(name: "territoryPrices", expected: expected)
            }
            prices[territory.trimmingCharacters(in: .whitespaces).uppercased()] = price
        }
        terms.territoryPrices = prices
    }

    /// A day argument, or nil when it's absent.
    static func day(_ name: String, in arguments: MCPToolArguments) throws -> Date? {
        guard let text = try arguments.optionalString(name) else { return nil }
        guard let day = NewIntroductoryOffer.day(from: text) else {
            throw MCPToolError.invalidArgument(name: name, expected: String(localized: "a day as yyyy-MM-dd"))
        }
        return day
    }

    /// The evidence, then the reason.
    static func evidence(from arguments: MCPToolArguments) throws -> [String] {
        try (arguments.optionalStrings("evidence") ?? []) + [arguments.optionalString("reason")].compactMap(\.self)
    }
}
