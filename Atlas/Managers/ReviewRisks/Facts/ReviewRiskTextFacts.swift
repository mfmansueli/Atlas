//
//  ReviewRiskTextFacts.swift
//  Atlas
//

import Foundation

/// Every store text pushed or waiting in Review & Push, in every
/// language and place. Where a queued change replaces a pushed text, only
/// the queued one is here: it's what App Review will see.
struct ReviewRiskTextFacts: Hashable, Sendable {
    var texts: [ReviewRiskText] = []
    /// The app's primary store locale, e.g. "en-US".
    var primaryLocale: String = "en-US"
    /// What the app may say: "For Kids" with a Kids age band, its approved
    /// name's words in the name and subtitle.
    var allowance = StoreTextGuidelineAllowance()

    init(texts: [ReviewRiskText] = [], primaryLocale: String = "en-US", allowance: StoreTextGuidelineAllowance = StoreTextGuidelineAllowance()) {
        self.texts = texts
        self.primaryLocale = primaryLocale
        self.allowance = allowance
    }

    /// Every language's value of one listing field.
    func listing(_ field: ListingField) -> [ReviewRiskText] {
        texts.filter { $0.place == .storeListing && $0.field == field }
    }

    /// The field in one language, or nil.
    func listing(_ field: ListingField, locale: String) -> ReviewRiskText? {
        texts.first { $0.place == .storeListing && $0.field == field && $0.locale == locale }
    }

    /// The locales the listing has, primary first.
    var listingLocales: [String] {
        var seen: [String] = []
        for text in texts where text.place == .storeListing && !seen.contains(text.locale) {
            seen.append(text.locale)
        }
        return seen.sorted { lhs, rhs in lhs == primaryLocale || (rhs != primaryLocale && lhs < rhs) }
    }
}
