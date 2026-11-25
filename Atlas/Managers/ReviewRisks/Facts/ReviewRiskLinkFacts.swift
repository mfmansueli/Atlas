//
//  ReviewRiskLinkFacts.swift
//  Atlas
//

import Foundation

/// The app's URLs and whether they open: per language its Privacy Policy,
/// Support and Marketing URLs as pushed, the Terms of Use links its
/// description has, and what opening each URL gave. `supportURLs` is
/// shared (1.2 asks for published contact details).
struct ReviewRiskLinkFacts: Hashable, Sendable {
    /// Locale → Support URL as written.
    var supportURLs: [String: String] = [:]
    /// Locale → Privacy Policy URL as written.
    var privacyPolicyURLs: [String: String] = [:]
    /// URL as written → what opening it gave.
    var statuses: [String: ReviewRiskURLStatus] = [:]
    /// Locale → Marketing URL as written.
    var marketingURLs: [String: String] = [:]
    /// Locale → the Terms of Use links in its description.
    var termsURLs: [String: [String]] = [:]
    /// The store locales, in App Store Connect's order.
    var locales: [String] = []
    var primaryLocale = "en-US"
    /// URLs left unopened: more than `ReviewRiskFactsLoader.urlProbes`.
    var unprobed: [String] = []

    init(
        supportURLs: [String: String] = [:], privacyPolicyURLs: [String: String] = [:], statuses: [String: ReviewRiskURLStatus] = [:],
        marketingURLs: [String: String] = [:], termsURLs: [String: [String]] = [:], locales: [String] = [], primaryLocale: String = "en-US",
        unprobed: [String] = []
    ) {
        self.supportURLs = supportURLs
        self.privacyPolicyURLs = privacyPolicyURLs
        self.statuses = statuses
        self.marketingURLs = marketingURLs
        self.termsURLs = termsURLs
        self.locales = locales
        self.primaryLocale = primaryLocale
        self.unprobed = unprobed
    }

    /// Every URL to open, distinct, most important first: privacy, support,
    /// terms, then marketing; the primary language's before the others.
    var urlsToProbe: [String] {
        let order = [primaryLocale] + locales.filter { $0 != primaryLocale }
        func urls(_ map: [String: String]) -> [String] {
            order.compactMap { map[$0] } + map.filter { !order.contains($0.key) }.sorted { $0.key < $1.key }.map(\.value)
        }
        let terms = order.flatMap { termsURLs[$0] ?? [] } + termsURLs.filter { !order.contains($0.key) }.sorted { $0.key < $1.key }.flatMap(\.value)
        var seen: Set<String> = []
        return (urls(privacyPolicyURLs) + urls(supportURLs) + terms + urls(marketingURLs))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
