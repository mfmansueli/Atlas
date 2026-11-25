//
//  PaywallDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The paywall's states as the Redesign canvas names them, over the main
/// window in Free, with the DEBUG store (U.S. prices, nothing charged):
///
/// - `pw-all`: from Accept All Languages on the Store Page, Yearly picked.
/// - `pw-auto`: from Autopilot in Screenshots, Monthly picked.
/// - `pw-price`: from suggested prices in Pricing.
/// - `pw-life`: from the toolbar's Pro button, Lifetime picked.
/// - `pw-compare`: from the toolbar, Compare Free and Pro open.
/// - `pw-done`: Yearly bought: "Your free trial has started", the date
///   and the reminder 2 days before, and Accept 13 Suggestions….
/// - `free-sp`, `free-pr`: the Store Page and Pricing in Free, no sheet.
enum PaywallDebugScenes {
    static let ids = ["pw-all", "pw-auto", "pw-price", "pw-life", "pw-compare", "pw-done", "free-sp", "free-pr"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard ids.contains(id) else { return nil }
        switch id {
        case "free-sp":
            return AnyView(DebugMainScene(section: .storePage, suggestions: SuggestionsDebugData.store(), isFree: true))
        case "free-pr":
            return AnyView(DebugMainScene(section: .subscriptionPricing, isFree: true))
        default:
            return AnyView(PaywallDebugScene(id: id))
        }
    }

    /// What was blocked: the numbers `sp-cc`'s suggestions give.
    static func context(for id: String) -> PaywallContext {
        switch id {
        case "pw-all", "pw-done": .acceptAllLanguages(suggestions: 13, languages: 9)
        case "pw-auto": .autopilot
        case "pw-price": .recommendedPrices(countries: 104)
        default: .menu
        }
    }

    static func section(for id: String) -> AppWorkspaceSection {
        switch id {
        case "pw-all", "pw-done": .storePage
        case "pw-auto": .screenshots
        case "pw-price": .subscriptionPricing
        default: .overview
        }
    }

    /// The toolbar's paywall has nothing to finish afterwards.
    static func continues(_ id: String) -> Bool {
        context(for: id) != .menu
    }

    /// The plan picked, the comparison, or the purchase made.
    @MainActor
    static func prepare(_ model: PaywallModel, for id: String) async {
        await model.load()
        // The sheet's own load may be the one reading the plans: wait for
        // them before picking or buying one.
        for _ in 0..<100 where model.offers.isEmpty {
            try? await Task.sleep(for: .milliseconds(50))
        }
        switch id {
        case "pw-auto": model.plan = .monthly
        case "pw-life": model.plan = .lifetime
        case "pw-compare": model.showCompare(true)
        case "pw-done": await model.buy()
        default: break
        }
    }
}
#endif
