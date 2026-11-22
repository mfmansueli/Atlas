//
//  VersionReviewsSummary.swift
//  Atlas
//

import Foundation

/// The newest version's reviews against the one before: average rating and
/// how many mention a crash. Shown above Reviews while Analytics says the
/// version crashes more, or its reviews mention crashes.
struct VersionReviewsSummary: Hashable, Sendable {
    var version: String
    var count: Int
    var average: Double
    var crashMentions: Int
    var previousVersion: String?
    var previousAverage: Double?

    /// Fewer reviews than this don't make an average worth showing.
    static let fewestReviews = 3

    /// nil without reviews that name a version.
    static func make(_ reviews: [AppReview], newest: String? = nil) -> VersionReviewsSummary? {
        let versions = Set(reviews.compactMap(\.version)).sorted(by: AppVersionOrder.isBefore)
        guard let version = newest ?? versions.last else { return nil }
        let these = reviews.filter { $0.version == version }
        guard !these.isEmpty else { return nil }
        let previous = versions.last { AppVersionOrder.isBefore($0, version) }
        let before = reviews.filter { $0.version != nil && $0.version == previous }
        return VersionReviewsSummary(
            version: version,
            count: these.count,
            average: average(these),
            crashMentions: these.filter(ReviewCrashMentions.mentionsCrash).count,
            previousVersion: before.count >= fewestReviews ? previous : nil,
            previousAverage: before.count >= fewestReviews ? average(before) : nil
        )
    }

    private static func average(_ reviews: [AppReview]) -> Double {
        reviews.isEmpty ? 0 : Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
    }

    /// "Reviews on 1.4: 3.1★ from 24 (1.3: 4.4★) · 5 mention a crash".
    var text: String {
        let stars = average.formatted(.number.precision(.fractionLength(1)))
        var line = String(localized: "Reviews on \(version): \(stars)★ from \(count)")
        if let previousVersion, let previousAverage {
            line += " " + String(localized: "(\(previousVersion): \(previousAverage.formatted(.number.precision(.fractionLength(1))))★)")
        }
        if crashMentions > 0 {
            line += " · " + (crashMentions == 1 ? String(localized: "1 mentions a crash") : String(localized: "\(crashMentions) mention a crash"))
        }
        return line
    }
}
