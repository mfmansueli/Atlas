//
//  PricingModeStore.swift
//  Atlas
//

import Foundation
import Observation

/// Each app's pricing mode and dismissed price suggestions, kept in
/// `UserDefaults`. An app without a mode hasn't opened Pricing yet: Pricing
/// then asks with a sheet, and everything else treats it as the default
/// from Settings.
@MainActor
@Observable
final class PricingModeStore {
    private(set) var modes: [StoreApp.ID: PricingMode]
    /// Settings → Pricing → "Pricing mode for new apps".
    var defaultMode: PricingMode

    private let defaults: UserDefaults?

    /// `defaults: nil` keeps everything in memory (tests, DEBUG scenes).
    init(defaults: UserDefaults? = .standard, defaultMode: PricingMode = .showSuggestions, modes: [StoreApp.ID: PricingMode] = [:]) {
        self.defaults = defaults
        self.defaultMode = defaultMode
        let saved = (defaults?.dictionary(forKey: Self.key) as? [String: String] ?? [:])
            .compactMapValues(PricingMode.init(rawValue:))
        self.modes = saved.merging(modes) { _, new in new }
        dismissedPriceSuggestions = (defaults?.dictionary(forKey: Self.dismissalsKey) as? [String: [String]] ?? [:]).mapValues(Set.init)
        reviewLaterProductIDs = (defaults?.dictionary(forKey: Self.reviewLaterKey) as? [String: [String]] ?? [:]).mapValues(Set.init)
    }

    /// The mode the person picked for this app, or nil before the first visit.
    func chosenMode(for appID: StoreApp.ID) -> PricingMode? {
        modes[appID]
    }

    /// The picked mode, or the default for apps that haven't been asked yet.
    func mode(for appID: StoreApp.ID) -> PricingMode {
        modes[appID] ?? defaultMode
    }

    func setMode(_ mode: PricingMode, for appID: StoreApp.ID) {
        modes[appID] = mode
        defaults?.set(modes.mapValues(\.rawValue), forKey: Self.key)
    }

    // MARK: - Dismissed price suggestions

    /// Per app, the products whose price suggestion the person dismissed on
    /// a Pricing card; Restore Dismissed brings them back.
    private(set) var dismissedPriceSuggestions: [StoreApp.ID: Set<String>]

    func isPriceSuggestionDismissed(productID: String, appID: StoreApp.ID) -> Bool {
        dismissedPriceSuggestions[appID]?.contains(productID) == true
    }

    func dismissPriceSuggestion(productID: String, appID: StoreApp.ID) {
        dismissedPriceSuggestions[appID, default: []].insert(productID)
        saveDismissals()
    }

    func restorePriceSuggestions(appID: StoreApp.ID) {
        dismissedPriceSuggestions[appID] = nil
        saveDismissals()
    }

    // MARK: - Recommendations to review later

    /// Per app, the product IDs (`com.example.app.premium.weekly`) of new
    /// subscriptions added with Apple's prices and the recommendations to
    /// review after the push: Pricing shows a banner with Review… for them.
    private(set) var reviewLaterProductIDs: [StoreApp.ID: Set<String>]

    func isReviewingLater(productID: String, appID: StoreApp.ID) -> Bool {
        reviewLaterProductIDs[appID]?.contains(productID) == true
    }

    func setReviewLater(_ isOn: Bool, productID: String, appID: StoreApp.ID) {
        if isOn {
            reviewLaterProductIDs[appID, default: []].insert(productID)
        } else {
            reviewLaterProductIDs[appID]?.remove(productID)
            if reviewLaterProductIDs[appID]?.isEmpty == true { reviewLaterProductIDs[appID] = nil }
        }
        defaults?.set(reviewLaterProductIDs.mapValues { $0.sorted() }, forKey: Self.reviewLaterKey)
    }

    private func saveDismissals() {
        defaults?.set(dismissedPriceSuggestions.mapValues { $0.sorted() }, forKey: Self.dismissalsKey)
    }

    private static let key = "pricingModes"
    private static let dismissalsKey = "dismissedPriceSuggestions"
    private static let reviewLaterKey = "reviewLaterPriceSuggestions"
}
