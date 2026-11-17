//
//  VersionRatingComparison.swift
//  Atlas
//

import Foundation

/// The written reviews of the current version against the ones before it:
/// "3.9 ★ since 1.3 · lower than before, sure".
struct VersionRatingComparison: Hashable, Sendable {
    var version: String
    /// The first review of that version.
    var since: Date
    var average: Double
    var count: Int
    var earlierAverage: Double
    var earlierCount: Int
    var outcome: ComparisonOutcome

    /// Reviews on each side below this are too few to compare.
    static let minimumCount = 10

    /// Nil when no review is listed under `version`, or none before it.
    static func make(reviews: [AppReview], version: String?) -> VersionRatingComparison? {
        guard let version else { return nil }
        let current = reviews.filter { $0.version == version }
        let earlier = reviews.filter { $0.version != version }
        guard let since = current.map(\.date).min(), let average = StarHistogram(current).average,
              let earlierAverage = StarHistogram(earlier).average else { return nil }
        return VersionRatingComparison(
            version: version, since: since, average: average, count: current.count,
            earlierAverage: earlierAverage, earlierCount: earlier.count,
            outcome: outcome(current.map(\.rating), against: earlier.map(\.rating))
        )
    }

    /// Two samples of star ratings compared by their means (Welch's test,
    /// read as a normal): "sure" beyond 99%, "fairly sure" beyond 90%.
    static func outcome(_ sample: [Int], against earlier: [Int]) -> ComparisonOutcome {
        guard sample.count >= minimumCount, earlier.count >= minimumCount else { return .tooFew }
        let (mean, variance) = moments(sample)
        let (earlierMean, earlierVariance) = moments(earlier)
        let spread = (variance / Double(sample.count) + earlierVariance / Double(earlier.count)).squareRoot()
        guard spread > 0 else { return mean == earlierMean ? .same : (mean > earlierMean ? .higher(.sure) : .lower(.sure)) }
        let score = (mean - earlierMean) / spread
        let confidence: ComparisonConfidence
        switch abs(score) {
        case 2.576...: confidence = .sure
        case 1.645...: confidence = .fairlySure
        default: return .same
        }
        return score > 0 ? .higher(confidence) : .lower(confidence)
    }

    private static func moments(_ values: [Int]) -> (mean: Double, variance: Double) {
        let count = Double(values.count)
        let mean = Double(values.reduce(0, +)) / count
        let squares = values.reduce(0.0) { $0 + (Double($1) - mean) * (Double($1) - mean) }
        return (mean, count > 1 ? squares / (count - 1) : 0)
    }

    /// "Since 1.3 (Nov 6) · 412 reviews".
    var sinceText: String {
        String(localized: "Since \(version) (\(ReviewText.day(since))) · \(ReviewText.reviews(count))")
    }

    /// "Lower than before 1.3: 4.7 from 2,980 reviews. Sure."
    var againstText: String {
        let earlier = String(localized: "\(ReviewText.rating(earlierAverage)) from \(ReviewText.reviews(earlierCount))")
        switch outcome {
        case .tooFew: return String(localized: "Too few reviews to compare with before \(version) (\(earlier)).")
        case .same: return String(localized: "About the same as before \(version): \(earlier).")
        case let .higher(confidence): return String(localized: "Higher than before \(version): \(earlier). \(Self.sentence(confidence))")
        case let .lower(confidence): return String(localized: "Lower than before \(version): \(earlier). \(Self.sentence(confidence))")
        }
    }

    private static func sentence(_ confidence: ComparisonConfidence) -> String {
        switch confidence {
        case .sure: String(localized: "Sure.")
        case .fairlySure: String(localized: "Fairly sure.")
        }
    }
}
