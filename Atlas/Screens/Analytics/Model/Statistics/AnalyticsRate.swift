//
//  AnalyticsRate.swift
//  Atlas
//

import Foundation

/// One rate as every Analytics view shows it: a percentage with its range,
/// the counts when they're too few to tell, or missing with a dash.
enum AnalyticsRate: Hashable, Sendable {
    /// Apple didn't give the numbers (role, vendor number, not split that way).
    case missing
    /// The step before has fewer than 30, or the step itself fewer than 3:
    /// shown as "1 of 40", with no percentage and no ▲▼.
    case tooFew(count: Int, total: Int)
    case measured(MeasuredRate)

    var measured: MeasuredRate? {
        if case let .measured(rate) = self { return rate }
        return nil
    }

    var isTooFew: Bool {
        if case .tooFew = self { return true }
        return false
    }

    /// The plain fraction, for sorting; nil when missing or nothing to divide by.
    var fraction: Double? {
        switch self {
        case .missing: nil
        case let .tooFew(count, total): total > 0 ? Double(count) / Double(total) : nil
        case let .measured(rate): rate.value
        }
    }

    /// "5.4%", "1 of 40" or "—".
    var text: String {
        switch self {
        case .missing: "—"
        case let .tooFew(count, total): String(localized: "\(AnalyticsText.count(count)) of \(AnalyticsText.count(total))")
        case let .measured(rate): AnalyticsText.percent(rate.value)
        }
    }

    /// The tooltip and VoiceOver value: the counts, the range and the
    /// average it's compared with.
    func detail(averageName: String? = nil, average: Double? = nil) -> String {
        switch self {
        case .missing:
            return String(localized: "Apple doesn't give this number.")
        case let .tooFew(count, total):
            return String(localized: "Too few to tell: \(AnalyticsText.count(count)) of \(AnalyticsText.count(total)). Rates this small move by chance.")
        case let .measured(rate):
            let range = String(
                localized: "\(AnalyticsText.percent(rate.value)) (\(AnalyticsText.count(rate.count)) of \(AnalyticsText.count(rate.total))). 90% likely between \(AnalyticsText.percent(rate.low)) and \(AnalyticsText.percent(rate.high))."
            )
            guard let average, let averageName else { return range }
            let standing = rate.standing.map { " \($0.title)." } ?? ""
            return range + " " + String(localized: "\(averageName)’s average: \(AnalyticsText.percent(average)).") + standing
        }
    }
}
