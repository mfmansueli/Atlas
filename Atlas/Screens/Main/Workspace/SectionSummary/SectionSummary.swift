//
//  SectionSummary.swift
//  Atlas
//

import Foundation

/// The summary line under a section's description (README-DS §9 “Section
/// summary”, §10 “Top of every section”): what waits, then the time it
/// takes, “3 suggestions · about 2 min · 2 in Review & Push”. Each open
/// suggestion counts half a minute, at least one minute in all. Changes
/// waiting in Review & Push count only in the sections that push them
/// from the page (Store Page, Screenshots, App Information, Pricing).
/// Nothing waiting hides the line.
struct SectionSummary: Equatable {
    /// Open suggestions in the section.
    let suggestions: Int
    /// The section's changes accepted or edited and not pushed yet.
    let notPushed: Int

    /// The sections whose suggestions the line counts.
    static let countsSuggestions: Set<AppWorkspaceSection> = [
        .storePage, .screenshots, .appInformation, .subscriptionPricing, .productPages, .inAppEvents, .reviews,
    ]

    /// The sections whose changes in Review & Push the line counts.
    static let countsNotPushed: Set<AppWorkspaceSection> = [.storePage, .screenshots, .appInformation, .subscriptionPricing]

    init(suggestions: Int, notPushed: Int) {
        self.suggestions = max(0, suggestions)
        self.notPushed = max(0, notPushed)
    }

    /// The line for `section`, from its open suggestions and its changes
    /// not pushed yet; nil when the section shows none (Overview,
    /// Analytics) or nothing waits.
    static func make(section: AppWorkspaceSection, suggestions: Int, notPushed: Int) -> SectionSummary? {
        let summary = SectionSummary(
            suggestions: countsSuggestions.contains(section) ? suggestions : 0,
            notPushed: countsNotPushed.contains(section) ? notPushed : 0
        )
        return summary.isEmpty ? nil : summary
    }

    var isEmpty: Bool { suggestions == 0 && notPushed == 0 }

    /// Half a minute a suggestion, rounded, never under one.
    var minutes: Int { max(1, (suggestions + 1) / 2) }

    /// “3 suggestions · about 2 min · 2 in Review & Push”; empty when
    /// nothing waits.
    var text: String {
        var parts: [String] = []
        if suggestions > 0 {
            parts.append(suggestionsText)
            parts.append(String(localized: "about \(minutes) min", comment: "kind:description"))
        }
        if notPushed > 0 { parts.append(notPushedText) }
        return parts.joined(separator: " · ")
    }

    /// The same for VoiceOver: “3 suggestions, about 2 minutes, 2 in
    /// Review & Push”.
    var accessibilityText: String {
        var parts: [String] = []
        if suggestions > 0 {
            parts.append(suggestionsText)
            parts.append(minutes == 1
                ? String(localized: "about 1 minute", comment: "kind:accessibility-label")
                : String(localized: "about \(minutes) minutes", comment: "kind:accessibility-label"))
        }
        if notPushed > 0 { parts.append(notPushedText) }
        return parts.joined(separator: ", ")
    }

    private var suggestionsText: String {
        suggestions == 1
            ? String(localized: "1 suggestion", comment: "kind:description")
            : String(localized: "\(suggestions) suggestions", comment: "kind:description")
    }

    private var notPushedText: String {
        String(localized: "\(notPushed) in Review & Push", comment: "kind:description")
    }
}
