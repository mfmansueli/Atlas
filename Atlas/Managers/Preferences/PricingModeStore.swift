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
        dismissedCountrySuggestions = (defaults?.dictionary(forKey: Self.countryDismissalsKey) as? [String: [String: [String]]] ?? [:])
            .mapValues { $0.mapValues(Set.init) }
        reviewLaterProductIDs = (defaults?.dictionary(forKey: Self.reviewLaterKey) as? [String: [String]] ?? [:]).mapValues(Set.init)
        strategies = Self.decoded([StoreApp.ID: PricingStrategy].self, defaults?.data(forKey: Self.strategiesKey)) ?? [:]
        strategySuggestions = Self.decoded([StoreApp.ID: PricingStrategySuggestion].self, defaults?.data(forKey: Self.strategySuggestionsKey)) ?? [:]
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
        dismissedCountrySuggestions[appID] = nil
        saveDismissals()
    }

    // MARK: - Dismissed country suggestions

    /// Per app and product, the countries (alpha-3) whose suggested price
    /// the person dismissed in Prices by Country; Restore Dismissed brings
    /// them back with the products'.
    private(set) var dismissedCountrySuggestions: [StoreApp.ID: [String: Set<String>]]

    func dismissedCountries(productID: String, appID: StoreApp.ID) -> Set<String> {
        dismissedCountrySuggestions[appID]?[productID] ?? []
    }

    func dismissCountrySuggestion(territoryID: String, productID: String, appID: StoreApp.ID) {
        dismissedCountrySuggestions[appID, default: [:]][productID, default: []].insert(territoryID)
        saveDismissals()
    }

    func restoreCountrySuggestion(territoryID: String, productID: String, appID: StoreApp.ID) {
        dismissedCountrySuggestions[appID]?[productID]?.remove(territoryID)
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

    // MARK: - Strategy

    /// Per app, the strategy the person set in Customize…; apps without one
    /// follow Settings → Pricing's defaults (`defaultStrategy`).
    private(set) var strategies: [StoreApp.ID: PricingStrategy]

    /// Settings → Pricing's strategy, as `AppPreferences.pricingDefaults`
    /// saves it; recommended without saved defaults (tests, DEBUG scenes).
    var defaultStrategy: PricingStrategy {
        Self.decoded(PricingStrategy.self, defaults?.data(forKey: Self.pricingDefaultsKey)) ?? .recommended
    }

    /// The strategy Pricing shows and suggests from for this app, and the
    /// one the price tools use over MCP.
    func strategy(for appID: StoreApp.ID) -> PricingStrategy {
        strategies[appID] ?? defaultStrategy
    }

    /// Whether the app's strategy is its own (Customize…) or Settings'.
    func hasOwnStrategy(_ appID: StoreApp.ID) -> Bool {
        strategies[appID] != nil
    }

    func setStrategy(_ strategy: PricingStrategy, for appID: StoreApp.ID) {
        guard strategies[appID] != strategy else { return }
        strategies[appID] = strategy
        defaults?.set(try? JSONEncoder().encode(strategies), forKey: Self.strategiesKey)
    }

    // MARK: - Strategy suggestions

    /// Per app, the strategy or mode an assistant suggested
    /// (`propose_pricing_strategy`), waiting on Pricing for Accept.
    private(set) var strategySuggestions: [StoreApp.ID: PricingStrategySuggestion]

    func strategySuggestion(for appID: StoreApp.ID) -> PricingStrategySuggestion? {
        strategySuggestions[appID]
    }

    /// Waits for the person; a newer one replaces it.
    func suggestStrategy(_ suggestion: PricingStrategySuggestion, for appID: StoreApp.ID) {
        strategySuggestions[appID] = suggestion
        saveStrategySuggestions()
    }

    /// Dismiss, Accept, or the assistant taking it back.
    func removeStrategySuggestion(for appID: StoreApp.ID) {
        guard strategySuggestions[appID] != nil else { return }
        strategySuggestions[appID] = nil
        saveStrategySuggestions()
    }

    private func saveStrategySuggestions() {
        defaults?.set(try? JSONEncoder().encode(strategySuggestions), forKey: Self.strategySuggestionsKey)
    }

    private static func decoded<Value: Decodable>(_ type: Value.Type, _ data: Data?) -> Value? {
        data.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }

    private func saveDismissals() {
        defaults?.set(dismissedPriceSuggestions.mapValues { $0.sorted() }, forKey: Self.dismissalsKey)
        defaults?.set(dismissedCountrySuggestions.mapValues { $0.mapValues { $0.sorted() } }, forKey: Self.countryDismissalsKey)
    }

    private static let key = "pricingModes"
    private static let dismissalsKey = "dismissedPriceSuggestions"
    private static let countryDismissalsKey = "dismissedCountryPriceSuggestions"
    private static let reviewLaterKey = "reviewLaterPriceSuggestions"
    private static let strategiesKey = "pricingStrategies"
    private static let strategySuggestionsKey = "pricingStrategySuggestions"
    /// `AppPreferences.pricingDefaults`' key: Settings → Pricing writes it.
    nonisolated static let pricingDefaultsKey = "pricingDefaults"
}
