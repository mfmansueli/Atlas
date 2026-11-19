//
//  InAppEventsViewModel+ArtworkStudio.swift
//  Atlas
//

import Foundation

/// The event's artwork (boards 40 and 47): its run with Claude, the
/// images it has (used, waiting in Review & Push or on the App Store), and
/// the Artwork panel's state. Make the Artwork… and Choose Files… go to
/// the section, which owns the Pro gate and the open panel.
extension InAppEventsViewModel {
    func artworkRun(of event: InAppEvent) -> EventArtworkRun? {
        artworkStudio?.run(appID: app.id, eventID: event.id)
    }

    /// The images waiting in Review & Push came from the run's used concept.
    func usedArtIsQueued(_ event: InAppEvent) -> Bool {
        guard let run = artworkRun(of: event), run.used != nil else { return false }
        let queued = Set(queue.changes(for: app.id, section: .inAppEvents).map(\.id))
        return run.queuedChangeIDs.contains(where: queued.contains)
    }

    /// The event's image of `kind` as it will be: the used concept's while
    /// it waits in Review & Push, else other art waiting there, else the
    /// App Store's, else none.
    func artSource(_ kind: InAppEventMedia.Kind, of event: InAppEvent, locale: String? = nil) -> InAppEventArtSource {
        if usedArtIsQueued(event), let run = artworkRun(of: event), let used = run.used, let still = used.still(kind, locale: locale ?? run.primaryLocale),
           still.kind == kind
        {
            return .file(path: still.path, isVideo: still.isVideo)
        }
        let queued = builder.queuedArtwork(for: event.id, in: queue.changes(for: app.id, section: .inAppEvents)).filter { $0.kind == kind }
        if let item = queued.first(where: { $0.locale == (locale ?? event.primaryLocale) }) ?? queued.first {
            return .file(path: item.push.path, isVideo: item.push.isVideo)
        }
        if let media = event.media(kind) { return media.imageURL.map(InAppEventArtSource.remote) ?? .withoutLink }
        return .none
    }

    /// The images the event still needs, counting what waits in Review & Push.
    func missingArt(of event: InAppEvent) -> [InAppEventMedia.Kind] {
        InAppEventMedia.Kind.allCases.filter { !artSource($0, of: event).exists }
    }

    /// The Artwork panel of the event's page.
    func artworkPanel(of event: InAppEvent, flow: EventArtworkFlow?) -> EventArtworkPanelState {
        let run = flow?.isStarted == true ? flow?.run : artworkRun(of: event)
        return EventArtworkPanelState.make(
            run: run, isChanging: flow?.isChanging ?? false, usedIsQueued: usedArtIsQueued(event), missing: missingArt(of: event),
            languages: max(1, event.localizations.count), canEdit: event.state.isEditable, isOver: event.state.isOver,
            preview: flow?.previewConcept
        )
    }

    func requestArtwork(_ action: EventArtworkRequest.Action, for event: InAppEvent) {
        artworkRequest = EventArtworkRequest(action: action, eventID: event.id)
    }

    /// A queued image that came from Use This Artwork: the Artwork panel
    /// shows it, so the proposals card doesn't.
    func isFromUsedArtwork(_ proposal: InAppEventArtworkProposal, of event: InAppEvent) -> Bool {
        guard let run = artworkRun(of: event), run.usedConceptID != nil else { return false }
        let ids = Set(run.queuedChangeIDs)
        return proposal.items.allSatisfy { ids.contains($0.changeID) }
    }
}
