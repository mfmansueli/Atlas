//
//  PriceConfidenceText.swift
//  Atlas
//

import Foundation

/// Formatting for HowSure's reasons and the evidence lines, locale-independent
/// like `PricingText` so tests can compare strings.
enum PriceConfidenceText {
    /// "+1.2", "−0.4" (U+2212), "0.0", in percentage points.
    static func points(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        let text = String(format: "%.1f", abs(rounded))
        if rounded > 0 { return "+" + text }
        if rounded < 0 { return "−" + text }
        return text
    }

    /// "May", in GMT, so a date doesn't shift with the Mac's zone.
    static func month(_ date: Date) -> String {
        date.formatted(monthStyle)
    }

    /// Whole days from `start` to `end`, in GMT.
    static func days(from start: Date, to end: Date) -> Int {
        Calendar.gmtGregorian.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// "1,240 page views", "1 page view".
    static func pageViews(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 page view", comment: "kind:other")
            : String(localized: "\(PricingText.grouped(count)) page views", comment: "kind:other")
    }

    /// "31 trials" or "31 starts", as the product counts them.
    static func starts(_ count: Int, trials: Bool) -> String {
        let number = PricingText.grouped(count)
        switch (trials, count == 1) {
        case (true, true): return String(localized: "1 trial", comment: "kind:other")
        case (true, false): return String(localized: "\(number) trials", comment: "kind:other")
        case (false, true): return String(localized: "1 start", comment: "kind:other")
        case (false, false): return String(localized: "\(number) starts", comment: "kind:other")
        }
    }

    private static let monthStyle = Date.FormatStyle(locale: Locale(identifier: "en_US"), timeZone: .gmt).month(.wide)
}
