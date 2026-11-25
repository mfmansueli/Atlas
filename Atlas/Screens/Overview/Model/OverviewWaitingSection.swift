//
//  OverviewWaitingSection.swift
//  Atlas
//

import Foundation

/// A row of the Overview's "suggestions to review": a section, what
/// it changes on the App Store, where its suggestions are, and how many.
struct OverviewWaitingSection: Identifiable, Hashable, Sendable {
    var section: AppWorkspaceSection
    var count: Int
    /// "Text in 6 languages, including 2 new pages", "Every caption reviewed".
    var detail: String

    var id: AppWorkspaceSection { section }

    var title: String { section.title }

    /// What the section changes: "The words on the page and in search".
    func what(appName: String) -> String {
        switch section {
        case .overview: ""
        case .storePage: String(localized: "The words on the page and in search")
        case .screenshots: String(localized: "The images people swipe through")
        case .subscriptionPricing: String(localized: "What \(appName) costs in each country")
        case .appInformation: String(localized: "Category, age rating, accessibility, App Review")
        case .analytics: String(localized: "Where people drop off, and what to change next")
        case .reviews: String(localized: "What people write about \(appName), and your replies")
        case .inAppEvents: String(localized: "Cards for what’s happening in \(appName)")
        case .nominations: String(localized: "What Apple’s editors read about what’s coming", comment: "kind:other")
        case .productPages: String(localized: "A page of its own for each audience")
        }
    }

    var systemImage: String { Self.icon(for: section) }

    /// "Review" with something to review, else "Open".
    var buttonTitle: String {
        count > 0 ? String(localized: "Review") : String(localized: "Open")
    }

    /// "Open Store Page, 32 suggestions to review".
    var accessibilityText: String {
        switch count {
        case 0: String(localized: "Open \(title)")
        case 1: String(localized: "Open \(title), 1 suggestion to review")
        default: String(localized: "Open \(title), \(count) suggestions to review")
        }
    }

    /// The list's title: "65 suggestions to review", or "Nothing to review".
    static func title(total: Int) -> String {
        switch total {
        case 0: String(localized: "Nothing to review")
        case 1: String(localized: "1 suggestion to review")
        default: String(localized: "\(total) suggestions to review")
        }
    }

    static func icon(for section: AppWorkspaceSection) -> String {
        section.systemImage
    }

    // MARK: - Rows

    /// What each section's suggestions are about, from what's open.
    struct Facts: Equatable {
        var counts: SectionBadgeCounts
        /// Languages with Store Page suggestions, and how many of them have
        /// no App Store page yet.
        var storePageLanguages = 0
        var newPages = 0
        /// Languages with a caption suggested.
        var captionLanguages = 0
        /// Pricing's count is a guess until Pricing has read every product.
        var isPricingEstimate = false
        /// Review screenshots in Pricing's count, waiting for Accept.
        var reviewShots = 0
        /// Shorter retention wordings an assistant suggested, already in
        /// Pricing's count (`SectionBadgeCounts.pricingCount`): the row
        /// names them (“and a retention message”).
        var retentionSuggestions = 0
        /// App Compliance answers an assistant suggested: App
        /// Information's row adds them.
        var complianceAnswers = 0
        /// "Age Rating, Accessibility", in the page column's order.
        var informationPages: [String] = []

        /// The row's count: the section's, with what it adds.
        func count(for section: AppWorkspaceSection) -> Int {
            switch section {
            case .appInformation: counts.count(for: section) + complianceAnswers
            default: counts.count(for: section)
            }
        }
    }

    /// Store Page, Screenshots, Pricing and App Information, in the design's
    /// order.
    static func rows(_ facts: Facts) -> [OverviewWaitingSection] {
        [
            row(.storePage, facts, detail: storePageDetail(facts)),
            row(.screenshots, facts, detail: facts.captionLanguages == 1
                ? String(localized: "Captions in 1 language")
                : String(localized: "Captions in \(facts.captionLanguages) languages"), done: String(localized: "Every caption reviewed")),
            row(.subscriptionPricing, facts, detail: pricingDetail(facts), done: String(localized: "Every price reviewed")),
            row(.appInformation, facts, detail: informationDetail(facts), done: String(localized: "Every page reviewed")),
        ]
    }

    private static func row(_ section: AppWorkspaceSection, _ facts: Facts, detail: String, done: String = "") -> OverviewWaitingSection {
        let count = facts.count(for: section)
        let fallback = done.isEmpty ? String(localized: "Every language reviewed") : done
        return OverviewWaitingSection(section: section, count: count, detail: count > 0 ? detail : fallback)
    }

    private static func storePageDetail(_ facts: Facts) -> String {
        let languages = facts.storePageLanguages == 1
            ? String(localized: "Text in 1 language")
            : String(localized: "Text in \(facts.storePageLanguages) languages")
        switch facts.newPages {
        case 0: return languages
        case 1: return String(localized: "\(languages), including 1 new page")
        default: return String(localized: "\(languages), including \(facts.newPages) new pages")
        }
    }

    /// “Prices for 2 products and a retention message”: the products with
    /// a price suggested, the review screenshots and the retention
    /// wordings.
    private static func pricingDetail(_ facts: Facts) -> String {
        var parts: [String] = []
        let products = facts.counts.count(for: .subscriptionPricing) - facts.reviewShots - facts.retentionSuggestions
        if products > 0 {
            parts.append(facts.isPricingEstimate ? String(localized: "Prices that likely hold people back")
                : products == 1 ? String(localized: "Prices for 1 product") : String(localized: "Prices for \(products) products"))
        }
        if facts.reviewShots > 0 {
            parts.append(facts.reviewShots == 1 ? String(localized: "1 review screenshot", comment: "kind:description")
                : String(localized: "\(facts.reviewShots) review screenshots", comment: "kind:description"))
        }
        if facts.retentionSuggestions > 0 {
            parts.append(parts.isEmpty ? String(localized: "A retention message", comment: "kind:description")
                : String(localized: "a retention message", comment: "kind:description"))
        }
        return parts.formatted(.list(type: .and))
    }

    /// The pages with suggestions, “Age Rating, App Compliance”, or how
    /// many answers wait when no page is named.
    private static func informationDetail(_ facts: Facts) -> String {
        guard facts.informationPages.isEmpty else { return facts.informationPages.joined(separator: ", ") }
        let count = facts.count(for: .appInformation)
        return count == 1 ? String(localized: "1 answer suggested", comment: "kind:done-state") : String(localized: "\(count) answers suggested", comment: "kind:done-state")
    }
}
