//
//  OverviewAfterReleaseRow.swift
//  Atlas
//

import Foundation

/// A line of the Overview's "After release" (README — redesign, November
/// 22): Analytics, Ratings & Reviews or Product Pages, with one line each,
/// a count (purple for suggestions, grey for anything else) and Open.
struct OverviewAfterReleaseRow: Identifiable, Hashable, Sendable {
    var section: AppWorkspaceSection
    var detail: String
    var count = 0
    /// The count is suggestions (purple), not findings (grey).
    var countsSuggestions = true

    var id: AppWorkspaceSection { section }

    /// The design's short names: "Ratings & Reviews", "Product Pages".
    var title: String {
        switch section {
        case .reviews: String(localized: "Ratings & Reviews")
        case .productPages: String(localized: "Custom Product Pages")
        default: section.title
        }
    }

    var accessibilityText: String {
        guard count > 0 else { return String(localized: "Open \(title)") }
        return countsSuggestions
            ? String(localized: "Open \(title), \(count) suggestions to review")
            : String(localized: "Open \(title), \(count) new findings")
    }

    // MARK: - Lines

    /// "3,120 downloads in 28 days · Page views per impression fell", or
    /// where setup stands.
    static func analytics(setup: AnalyticsSetup, report: FunnelReport?, newFindings: Int) -> OverviewAfterReleaseRow {
        let detail: String = switch setup {
        case .off: String(localized: "Not turned on · see where people drop off before paying")
        case .waiting: String(localized: "Apple is preparing the reports")
        case .keyCannotAsk: String(localized: "Needs an Admin key to ask Apple for reports")
        case .ready:
            if let report {
                [report.totals.downloads.map { String(localized: "\(AnalyticsText.count($0)) downloads in \(report.days) days") }, report.callout.title]
                    .compactMap(\.self)
                    .joined(separator: " · ")
            } else {
                String(localized: "No numbers yet")
            }
        }
        return OverviewAfterReleaseRow(section: .analytics, detail: detail, count: newFindings, countsSuggestions: false)
    }

    /// "24 reviews need a reply, in 9 languages", with the suggested
    /// replies as the count.
    static func reviews(archive: ReviewsArchive, isPro: Bool) -> OverviewAfterReleaseRow {
        guard archive.fetchedAt != nil else {
            return OverviewAfterReleaseRow(section: .reviews, detail: String(localized: "Not read yet"))
        }
        var detail = needText(archive)
        if detail.hasSuffix(".") { detail.removeLast() }
        return OverviewAfterReleaseRow(section: .reviews, detail: detail, count: isPro ? archive.openSuggestionCount : 0)
    }

    /// "6 pages · 3 visible on the App Store · 1 rejected".
    static func productPages(_ summary: ProductPagesOverviewSummary?) -> OverviewAfterReleaseRow {
        OverviewAfterReleaseRow(
            section: .productPages,
            detail: summary?.line ?? String(localized: "Not read yet"),
            count: summary?.suggestionCount ?? 0
        )
    }

    /// "24 reviews need a reply, in 9 languages."
    static func needText(_ archive: ReviewsArchive) -> String {
        let count = archive.needsReplyCount
        guard count > 0 else { return String(localized: "Every review that needs a reply has one.") }
        let languages = archive.needsReplyLanguageCount
        let reviews = count == 1 ? String(localized: "1 review needs a reply") : String(localized: "\(ReviewText.count(count)) reviews need a reply")
        return languages > 1 ? String(localized: "\(reviews), in \(ReviewText.languages(languages)).") : "\(reviews)."
    }
}
