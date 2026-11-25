//
//  WatchEventFacts.swift
//  Atlas
//

import Foundation

/// What Look for Improvements checks in one In-App Event: when its card
/// shows, and what's still missing for App Review and its languages.
struct WatchEventFacts: Identifiable, Hashable, Sendable {
    var id: InAppEvent.ID
    var name: String
    /// Still a draft, ready for review or rejected.
    var isEditable: Bool
    /// When its card is set to show.
    var deadline: Date?
    /// `InAppEventReviewNeed` names: "deepLink", "card"…
    var missingForReview: [String] = []
    /// `InAppEventDateWarning` names: "eventStartsSoon"…
    var reviewWarnings: [String] = []
    /// The store page's languages the event isn't written in, less those
    /// with a suggestion waiting.
    var missingLanguages: [String] = []

    init(
        id: InAppEvent.ID, name: String, isEditable: Bool, deadline: Date?, missingForReview: [String] = [], reviewWarnings: [String] = [],
        missingLanguages: [String] = []
    ) {
        self.id = id
        self.name = name
        self.isEditable = isEditable
        self.deadline = deadline
        self.missingForReview = missingForReview
        self.reviewWarnings = reviewWarnings
        self.missingLanguages = missingLanguages
    }

    /// `storeLocales`: the store page's languages, nil when unknown.
    init(_ event: InAppEvent, storeLocales: [String]?, suggestedLocales: Set<String>, now: Date) {
        let written = Set(event.localizations.map(\.locale))
        let name = event.primaryLocalization?.name ?? ""
        self.init(
            id: event.id,
            name: name.isEmpty ? event.referenceName : name,
            isEditable: event.state.isEditable,
            deadline: event.dates?.publishStart,
            missingForReview: event.reviewNeeds(now: now).map(\.mcpValue),
            reviewWarnings: event.dates.map { InAppEventDateWarning.warnings(for: $0, now: now).map(\.mcpValue) } ?? [],
            missingLanguages: (storeLocales ?? []).filter { !written.contains($0) && !suggestedLocales.contains($0) }
        )
    }

    /// Everything that's missing or warned about.
    var issueCount: Int {
        missingForReview.count + reviewWarnings.count + missingLanguages.count
    }
}
