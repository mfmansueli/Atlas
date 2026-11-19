//
//  EventArtworkPage.swift
//  Atlas
//

import Foundation

/// An HTML page for one event's card or details page in one
/// language, as render_event_artwork gets it.
struct EventArtworkPage: Sendable {
    var html: String
    /// The name Apple gets; nil names it after the event, kind and language.
    var fileName: String?
    var kind: InAppEventMedia.Kind
    var locale: String
    var event: InAppEvent
    var app: StoreApp

    var request: ArtworkWebRequest {
        ArtworkWebRequest(
            html: html, kind: InAppEventArtworkRules.artworkKind(for: kind), locale: locale,
            isRightToLeft: StoreLocaleCatalog.locale(code: locale)?.isRTL ?? false, headline: "", appName: app.name
        )
    }

    /// The still's name: the given one, else the event's, kind's and
    /// language's.
    var stillName: String {
        fileName ?? InAppEventArtworkFiles.renderedName(event: event.referenceName, kind: kind, locale: locale)
    }

    /// The loop's name: the same, as a .mov.
    var movieName: String {
        let stem = (stillName as NSString).deletingPathExtension
        return (stem.isEmpty ? "event-\(kind.mcpValue)" : stem) + ".mov"
    }
}
