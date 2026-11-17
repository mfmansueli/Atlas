//
//  InAppEventsViewModel+Artwork.swift
//  Atlas
//

import Foundation

/// The cards and details pages an assistant proposed for an event: shown
/// in its Images and video with Accept and Dismiss.
extension InAppEventsViewModel {
    func artworkProposals(of event: InAppEvent) -> [InAppEventArtworkProposal] {
        InAppEventArtworkProposal.grouped(builder.queuedArtwork(for: event.id, in: queue.changes(for: app.id, section: .inAppEvents)))
    }

    /// The texts laid over a proposal's preview: the language being
    /// viewed when the art goes into it, else the first one it goes into.
    func overlayTexts(for proposal: InAppEventArtworkProposal, of event: InAppEvent) -> InAppEventArtworkOverlayTexts {
        let locale = proposal.locales.contains(localeCode) ? localeCode : proposal.locales.first ?? localeCode
        return InAppEventArtworkOverlayTexts(event: event, kind: proposal.kind, locale: locale, appName: app.name)
    }

    /// Keeps the art: it can be pushed from Review & Push now.
    func acceptArtwork(_ proposal: InAppEventArtworkProposal) {
        queue.accept(ids: proposal.items.map(\.changeID))
        toast = ToastMessage(text: String(localized: "\(proposal.kind.title) accepted · waiting in Review & Push"))
    }

    func dismissArtwork(_ proposal: InAppEventArtworkProposal) {
        queue.discard(ids: proposal.items.map(\.changeID))
    }
}
