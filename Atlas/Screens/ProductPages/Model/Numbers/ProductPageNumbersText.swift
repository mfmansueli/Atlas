//
//  ProductPageNumbersText.swift
//  Atlas
//

import Foundation

/// How the list writes a page's numbers: 151K, 9,200 and 31.7%.
enum ProductPageNumbersText {
    /// 10 000 and over in thousands with one decimal ("18.4K", "151K",
    /// "10K"); below, with thousands separators ("9,200", "96").
    static func number(_ value: Int, locale: Locale = .current) -> String {
        guard value >= 10000 else { return value.formatted(.number.grouping(.automatic).locale(locale)) }
        let thousands = (Double(value) / 1000 * 10).rounded() / 10
        return thousands.formatted(.number.precision(.fractionLength(0...1)).locale(locale)) + "K"
    }

    /// "151K → 8,050 → 2,550".
    static func funnel(_ numbers: ProductPageNumbers, locale: Locale = .current) -> String {
        [numbers.impressions, numbers.pageViews, numbers.downloads].map { number($0, locale: locale) }.joined(separator: " → ")
    }

    /// "151K impressions, 8,050 page views, 2,550 downloads", for VoiceOver.
    static func spokenFunnel(_ numbers: ProductPageNumbers) -> String {
        String(localized: "\(number(numbers.impressions)) impressions, \(number(numbers.pageViews)) page views, \(number(numbers.downloads)) downloads")
    }

    /// "31.7%".
    static func rate(_ rate: Double, locale: Locale = .current) -> String {
        (rate / 100).formatted(.percent.precision(.fractionLength(1)).locale(locale))
    }

    /// The line instead of numbers, for a page nobody sees yet.
    static func noNumbers(for page: ProductPage) -> String {
        if page.state.isApproved {
            return page.isVisible ? String(localized: "No visits yet") : String(localized: "Hidden, so nobody sees it")
        }
        return String(localized: "Numbers start once it’s approved and visible")
    }
}
