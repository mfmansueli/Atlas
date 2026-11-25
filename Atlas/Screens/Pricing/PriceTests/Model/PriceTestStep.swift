//
//  PriceTestStep.swift
//  Atlas
//

import Foundation

/// How a price test moves the region's prices (board 76): 10, 20 or 30%
/// lower, 10 or 20% higher, or each country to its suggested
/// purchasing-power price. Every new price is rounded to one of Apple's
/// price points.
enum PriceTestStep: Hashable, Codable, Sendable {
    case percent(Int)
    /// Only countries whose suggested price differs from today's.
    case suggested

    /// The segmented control's order.
    static let choices: [PriceTestStep] = [.percent(-10), .percent(-20), .percent(-30), .percent(10), .percent(20), .suggested]

    /// "−20%", "+10%", "Suggested".
    var title: String {
        switch self {
        case let .percent(value): PricingText.signedPercent(value)
        case .suggested: String(localized: "Suggested", comment: "kind:label")
        }
    }

    /// "20% lower", "10% higher", "at suggested prices", for sentences.
    var phrase: String {
        switch self {
        case let .percent(value) where value < 0: String(localized: "\(abs(value))% lower", comment: "kind:label")
        case let .percent(value): String(localized: "\(value)% higher", comment: "kind:label")
        case .suggested: String(localized: "at suggested prices", comment: "kind:label")
        }
    }

    /// Every country's price goes up.
    var isRaise: Bool {
        if case let .percent(value) = self { return value > 0 }
        return false
    }

    /// Prices go down everywhere, so existing subscribers who renew pay less.
    var isDecrease: Bool {
        if case let .percent(value) = self { return value < 0 }
        return false
    }

    /// Test Again's smaller step: −30% → −20%, −20% → −10%, +20% → +10%;
    /// suggested prices try −10% for the whole region.
    var smaller: PriceTestStep {
        switch self {
        case let .percent(value) where abs(value) > 10: .percent(value > 0 ? value - 10 : value + 10)
        case .percent: self
        case .suggested: .percent(-10)
        }
    }

    /// As the MCP tools write it: "-20", "10", "suggested".
    var argument: String {
        switch self {
        case let .percent(value): String(value)
        case .suggested: "suggested"
        }
    }

    init?(argument: String) {
        let text = argument.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "%", with: "").replacingOccurrences(of: "\u{2212}", with: "-")
        if text == "suggested" {
            self = .suggested
            return
        }
        guard let value = Int(text), let step = Self.choices.first(where: { $0 == .percent(value) }) else { return nil }
        self = step
    }
}
