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

    /// The banner's bold lead (Redesign, 23 November): “Version 1.4
    /// averages 3.9 ★ from 11 reviews; 1.3 averaged 4.7 ★.”
    var lead: String {
        let stars = average.formatted(.number.precision(.fractionLength(1)))
        guard let previousVersion, let previousAverage else {
            return count == 1
                ? String(localized: "Version \(version) averages \(stars) ★ from 1 review.", comment: "kind:banner")
                : String(localized: "Version \(version) averages \(stars) ★ from \(count) reviews.", comment: "kind:banner")
        }
        let before = previousAverage.formatted(.number.precision(.fractionLength(1)))
        return count == 1
            ? String(localized: "Version \(version) averages \(stars) ★ from 1 review; \(previousVersion) averaged \(before) ★.", comment: "kind:banner")
            : String(
                localized: "Version \(version) averages \(stars) ★ from \(count) reviews; \(previousVersion) averaged \(before) ★.",
                comment: "kind:banner"
            )
    }

    /// What follows the lead: “6 of the 11 mention a crash, and crashes are
    /// 3.2× higher on 1.4.”; nil when there's neither.
    func detail(crashTimes: Double?) -> String? {
        let times = crashTimes.map(AnalyticsText.times)
        switch (crashMentions > 0, times) {
        case let (true, times?):
            return String(localized: "\(crashMentions) of the \(count) mention a crash, and crashes are \(times) higher on \(version).", comment: "kind:banner")
        case (true, nil):
            return String(localized: "\(crashMentions) of the \(count) mention a crash.", comment: "kind:banner")
        case let (false, times?):
            return String(localized: "Crashes are \(times) higher on \(version).", comment: "kind:banner")
        case (false, nil):
            return nil
        }
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
