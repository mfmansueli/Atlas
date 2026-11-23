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
    /// Sections where Autopilot waits for the person (the guided run's
    /// Pick, Choose or Review; replies Reply Automatically left): a purple
    /// mark beside the count, as the toolbar's purple button says.
    let needsYou: Set<AppWorkspaceSection>
    /// New Analytics findings to read: a gray count, since purple stays
    /// for suggestions to accept.
    private let newFindings: Int

    init(_ counts: [AppWorkspaceSection: Int] = [:], newFindings: Int = 0, needsYou: Set<AppWorkspaceSection> = []) {
        self.counts = counts
        self.newFindings = newFindings
        self.needsYou = needsYou
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
        counts[.appInformation, default: 0] += extras.complianceAnswers
        counts[.productPages, default: 0] += extras.productPages
        self.counts = counts
        newFindings = extras.newFindings
        needsYou = extras.needsYou
    }

    /// The counts that don't come from field suggestions.
    struct Extras: Equatable {
        /// New Analytics findings to read.
        var newFindings = 0
        /// Replies an assistant suggested, waiting for Send Reply.
        var reviewReplies = 0
        /// Languages of In-App Events with a suggestion or a revision the
        /// section shows (`InAppEventsStore.count(for:changes:)`).
        var eventLanguages = 0
        /// App Compliance answers an assistant suggested, still open.
        var complianceAnswers = 0
        /// Suggested pages and promotional texts.
        var productPages = 0
        /// Sections where Autopilot waits for the person.
        var needsYou: Set<AppWorkspaceSection> = []
    }

    /// Where Autopilot waits for the person: Screenshots while the guided
    /// run is at Pick, Choose or Review; Reviews while Reply Automatically
    /// left replies for them.
    @MainActor
    static func needsYou(appID: StoreApp.ID, repliesArePro: Bool) -> Set<AppWorkspaceSection> {
        needsYou(run: AutopilotCenter.shared.run(for: appID), autoReplyNeeds: repliesArePro ? AutoReplyCenter.shared.needsYouCount(for: appID) : 0)
    }

    static func needsYou(run: AutopilotRun?, autoReplyNeeds: Int) -> Set<AppWorkspaceSection> {
        var sections: Set<AppWorkspaceSection> = []
        if let run, WorkspaceAutopilotState.screenshotNeeds(run) != nil { sections.insert(.screenshots) }
        if autoReplyNeeds > 0 { sections.insert(.reviews) }
        return sections
    }

    /// The App Compliance answers waiting for the person: the section's
    /// exact count once it read what App Store Connect has, else the
    /// suggestions kept on this Mac.
    @MainActor
    static func complianceCount(appID: StoreApp.ID, model: AppInformationViewModel?, notes: any AppInformationNotesStore) -> Int {
        if let model, model.complianceReport != nil { return model.complianceSuggestions.count }
        return notes.notes(for: appID).complianceSuggestions.count
    }

    /// Products with an open price suggestion or a review screenshot to
    /// accept: Pricing's count of prices once it has read every product
    /// this launch; before that, 1 when the product the
    /// summary describes has prices likely holding people back and nothing
    /// for it is queued or dismissed. Apps set to Keep my prices have none.
    @MainActor
    static func pricingCount(appID: StoreApp.ID, summaries: AppSummaryStore, modes: PricingModeStore, changes: ChangeQueue) -> Int {
        // Review screenshots an assistant made, waiting for Accept.
        let shots = changes.changes(for: appID, section: .subscriptionPricing).count {
            $0.awaitingAcceptance != nil && $0.id.hasPrefix(PurchaseReviewScreenshotChangeBuilder.idPrefix)
        }
        return shots + pricePricingCount(appID: appID, summaries: summaries, modes: modes, changes: changes)
    }

    /// The price suggestions alone.
    @MainActor
    private static func pricePricingCount(appID: StoreApp.ID, summaries: AppSummaryStore, modes: PricingModeStore, changes: ChangeQueue) -> Int {
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
        let text = countText(for: section)
        return needsYou.contains(section) ? String(localized: "\(text), Autopilot needs you") : text
    }

    private func countText(for section: AppWorkspaceSection) -> String {
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
        let parts = AppWorkspaceSection.allCases.filter { count(for: $0) > 0 || needsYou.contains($0) }.map(accessibilityText)
        return parts.isEmpty ? String(localized: "No suggestions to review") : parts.joined(separator: ". ")
    }
}
