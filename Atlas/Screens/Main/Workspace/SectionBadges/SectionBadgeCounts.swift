//
//  SectionBadgeCounts.swift
//  Atlas
//

import Foundation

/// How many suggestions wait in each workspace section, for the counts in
/// the sidebar and the section menu. Sections without suggestions have no
/// count.
struct SectionBadgeCounts: Equatable {
    /// More than this reads "99+".
    static let maximumShown = 99

    private let counts: [AppWorkspaceSection: Int]
    /// New Analytics findings to read: a gray count, since purple stays
    /// for suggestions to accept.
    private let newFindings: Int

    init(_ counts: [AppWorkspaceSection: Int] = [:], newFindings: Int = 0) {
        self.counts = counts
        self.newFindings = newFindings
    }

    /// The open field suggestions, captions an assistant suggested, from
    /// Pricing products with an open price suggestion, and what `extras`
    /// adds: Reviews' suggested replies, In-App Events' suggested
    /// languages and Analytics' new findings.
    @MainActor
    init(appID: StoreApp.ID, suggestions: FieldSuggestionStore, screenshots: ScreenshotsDocumentCenter? = nil, pricing: Int = 0, extras: Extras = Extras()) {
        var counts: [AppWorkspaceSection: Int] = [:]
        for area in SuggestionArea.allCases {
            counts[area.section, default: 0] += suggestions.toReview(for: appID, area: area).count
        }
        counts[.screenshots, default: 0] += screenshots?.openCaptionCount(appID: appID) ?? 0
        counts[.subscriptionPricing, default: 0] += pricing
        counts[.reviews, default: 0] += extras.reviewReplies
        counts[.inAppEvents, default: 0] += extras.eventLanguages
        self.counts = counts
        newFindings = extras.newFindings
    }

    /// The counts that don't come from field suggestions.
    struct Extras: Equatable {
        /// New Analytics findings to read.
        var newFindings = 0
        /// Replies an assistant suggested, waiting for Send Reply.
        var reviewReplies = 0
        /// Languages of In-App Events an assistant suggested.
        var eventLanguages = 0
    }

    /// Products with an open price suggestion: Pricing's count once it has
    /// read every product this launch; before that, 1 when the product the
    /// summary describes has prices likely holding people back and nothing
    /// for it is queued or dismissed. Apps set to Keep my prices have none.
    @MainActor
    static func pricingCount(appID: StoreApp.ID, summaries: AppSummaryStore, modes: PricingModeStore, changes: ChangeQueue) -> Int {
        guard modes.mode(for: appID).showsSuggestions else { return 0 }
        if let exact = summaries.pricingSuggestionCounts[appID] { return exact }
        guard let summary = summaries.pricing[appID]?.value, summary.sellsAnything, (summary.heldBackTerritoryCount ?? 0) > 0,
              modes.dismissedPriceSuggestions[appID]?.isEmpty ?? true,
              changes.changes(for: appID, section: .subscriptionPricing).isEmpty
        else { return 0 }
        return 1
    }

    /// Every section's suggestions together, for the app in the app menu.
    var total: Int {
        counts.values.reduce(0, +)
    }

    func count(for section: AppWorkspaceSection) -> Int {
        section == .analytics ? newFindings : counts[section] ?? 0
    }

    /// Whether the section's count is the gray one.
    func isNeutral(_ section: AppWorkspaceSection) -> Bool {
        section == .analytics
    }

    /// "12", "99+", or nil when the section has none.
    func text(for section: AppWorkspaceSection) -> String? {
        let count = count(for: section)
        guard count > 0 else { return nil }
        return count > Self.maximumShown ? "\(Self.maximumShown)+" : "\(count)"
    }

    /// "Store Page, 12 suggestions to review", "Analytics, 2 new
    /// findings", or just the section's name.
    func accessibilityText(for section: AppWorkspaceSection) -> String {
        let count = count(for: section)
        guard count > 0 else { return section.title }
        if isNeutral(section) {
            return count == 1 ? String(localized: "\(section.title), 1 new finding") : String(localized: "\(section.title), \(count) new findings")
        }
        return count == 1
            ? String(localized: "\(section.title), 1 suggestion to review")
            : String(localized: "\(section.title), \(count) suggestions to review")
    }

    /// Every section's exact count, for VoiceOver: "Store Page, 12
    /// suggestions to review. App Information, 1 suggestion to review."
    var accessibilitySummary: String {
        let parts = AppWorkspaceSection.allCases.filter { count(for: $0) > 0 }.map(accessibilityText)
        return parts.isEmpty ? String(localized: "No suggestions to review") : parts.joined(separator: ". ")
    }
}
