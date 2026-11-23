//
//  InAppEventsViewModel+Gallery.swift
//  Atlas
//

import Foundation

/// The gallery of events and the event page (board 40): opening an event,
/// going back, and what each tile says.
extension InAppEventsViewModel {
    /// A tile, the switch menu or the Overview: the event's page, on the
    /// card. The language stays when the event has it.
    func open(_ id: InAppEvent.ID) {
        select(id)
        guard selectedEvent != nil else { return }
        previewKind = .card
        isSwitchMenuShown = false
        showsEvent = true
    }

    /// ‹ Events and All Events.
    func showGallery() {
        isSwitchMenuShown = false
        artworkFlow?.closeViewer()
        showsEvent = false
    }

    /// Languages of `event` with a suggestion waiting.
    func suggestedCount(of event: InAppEvent) -> Int {
        guard event.state.isEditable else { return 0 }
        return languages(of: event).count { $0.state == .suggested }
    }

    /// Written languages of `event` with a revision waiting.
    func revisionCount(of event: InAppEvent) -> Int {
        guard event.state.isEditable else { return 0 }
        return languages(of: event).count { $0.state == .revision }
    }

    /// "3 concepts ready" on the card: concepts in, none used.
    func readyConcepts(of event: InAppEvent) -> Int? {
        guard event.state.isEditable, let run = artworkRun(of: event), run.isReady, run.revisingID == nil else { return nil }
        let usedIsCurrent = run.used != nil && (usedArtIsQueued(event) || missingArt(of: event).isEmpty)
        return usedIsCurrent ? nil : run.concepts.count
    }

    /// "Dec 1 – Dec 31 · Shows on the App Store from Nov 24".
    func tileDates(of event: InAppEvent) -> String {
        "\(event.datesText) · \(Self.publishText(event, now: now()))"
    }

    /// The tile's note: what a draft still needs, else how it went.
    func tileNote(of event: InAppEvent) -> InAppEventTileNote {
        let languages = ReviewText.languages(max(1, event.localizations.count))
        switch status(of: event) {
        case let .goesWithVersion(version):
            let line = event.state.isSubmitted
                ? String(localized: "Submitted with \(app.name) \(version)")
                : String(localized: "Goes to App Review with \(app.name) \(version)")
            return InAppEventTileNote(text: "\(line) · \(languages)", tone: .secondary)
        case .ended, .archived:
            if let downloads = results[event.id]?.downloads {
                return InAppEventTileNote(text: String(localized: "\(downloads.formatted()) downloads from the event"), tone: .secondary)
            }
            return InAppEventTileNote(text: languages, tone: .secondary)
        case .waitingForReview, .inReview, .approved, .live:
            return InAppEventTileNote(text: languages, tone: .secondary)
        case .draft, .rejected:
            return InAppEventTileNote.make(draftParts(of: event), done: String(localized: "Ready to submit"))
        }
    }

    private func draftParts(of event: InAppEvent) -> [InAppEventTileNote.Part] {
        var parts: [InAppEventTileNote.Part] = []
        let run = artworkRun(of: event)
        if let run, run.isDrawing {
            parts.append(.init(text: String(localized: "Drawing · \(run.designedCount) of \(run.expectedCount) ready")))
        } else if let count = readyConcepts(of: event) {
            parts.append(.init(text: count == 1 ? String(localized: "1 concept to choose from") : String(localized: "\(count) concepts to choose from")))
        } else {
            let missing = missingArt(of: event)
            if !missing.isEmpty {
                let text = missing == [.card] ? String(localized: "Event card missing")
                    : missing == [.details] ? String(localized: "Event details image missing")
                    : String(localized: "Event card and event details missing")
                parts.append(.init(text: text, isWarning: true))
            }
        }
        if reviewItems(of: event).contains(where: { $0.need?.dateField != nil && $0.state == .missing }) {
            parts.append(.init(text: String(localized: "Its dates need a fix"), isWarning: true))
        }
        let suggested = suggestedCount(of: event)
        if suggested > 0 { parts.append(.init(text: String(localized: "\(ReviewText.languages(suggested)) suggested"))) }
        let revised = revisionCount(of: event)
        if revised > 0 { parts.append(.init(text: String(localized: "Revision suggested for \(ReviewText.languages(revised))"))) }
        return parts
    }

    /// "Winter Reflection 2026, Draft. 3 concepts to choose from".
    func tileLabel(of event: InAppEvent) -> String {
        "\(event.referenceName), \(status(of: event).title). \(tileNote(of: event).text)"
    }
}
