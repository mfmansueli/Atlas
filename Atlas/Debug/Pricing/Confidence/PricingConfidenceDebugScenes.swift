//
//  PricingConfidenceDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// HowSure and pooled evidence on Lumen Plus Annual's Prices by Country,
/// with sample sales (`DebugPricingConfidenceSales`) and the Reason column:
///
/// - `pr-prod-nosales`: Alba-like, 79 page views and no sales yet: Not
///   very sure, "No sales yet, so purchasing power alone."
/// - `pr-prod-thin`: Portugal (40 page views) borrows Europe's sales,
///   selected; its Reason reads "Uses Europe’s sales" (`pr-prod-borrowed`
///   adds the Source column).
/// - `pr-prod-fairly`: most traffic in countries with 300 page views and
///   10 trials of their own: Fairly sure.
/// - `pr-prod-sure`: earlier May changes with a clear lift carry over 80%
///   of the traffic: Sure, with Brazil's popover open.
/// - `pr-prod-matched`: every price already at its suggestion: no banner,
///   "Your prices match local purchasing power in N countries."
///   (`pr-prod-none` already names the dismissed-suggestion scene.)
enum PricingConfidenceDebugScenes {
    static let ids = ["pr-prod-nosales", "pr-prod-thin", "pr-prod-fairly", "pr-prod-sure", "pr-prod-matched"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "pr-prod-nosales": AnyView(PricingConfidenceDebugHost(scenario: .noSales))
        case "pr-prod-thin": AnyView(PricingConfidenceDebugHost(scenario: .thin, focusedTerritory: "PRT"))
        case "pr-prod-fairly": AnyView(PricingConfidenceDebugHost(scenario: .fairly))
        case "pr-prod-sure": AnyView(PricingConfidenceDebugHost(scenario: .sure, popoverTerritory: "BRA"))
        case "pr-prod-matched": AnyView(PricingConfidenceDebugHost(scenario: .matched))
        default: nil
        }
    }
}
#endif
