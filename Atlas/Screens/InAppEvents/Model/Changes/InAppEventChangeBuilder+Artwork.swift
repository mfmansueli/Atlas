//
//  InAppEventChangeBuilder+Artwork.swift
//  Atlas
//

import Foundation

/// An event's card or details page as Review & Push changes: one per
/// language, `inAppEvents.<appID>.<eventID>.artwork.<card|details>.<locale>`,
/// uploading the file into that localization and replacing what it had of
/// that kind. An assistant's waits for the person to accept it.
extension InAppEventChangeBuilder {
    static let artworkSegment = "artwork"

    func artworkChangeID(eventID: String, kind: InAppEventMedia.Kind, locale: String) -> String {
        "\(idPrefix)\(eventID).\(Self.artworkSegment).\(kind.mcpValue).\(locale)"
    }

    /// The change that uploads `report`'s file into `localization`.
    func artworkChange(
        _ report: InAppEventArtworkReport, into localization: InAppEventLocalization, of event: InAppEvent, source: ChangeSource
    ) -> PendingChange {
        artworkChange(
            report, localizationID: localization.id, locale: localization.locale,
            oldMedia: localization.media.first { $0.kind == report.kind }, of: event, source: source
        )
    }

    /// The change that uploads `report`'s file into a language whose texts
    /// are queued and that the push creates first: it names the language by
    /// its locale (`EventLocalizationPlaceholder`).
    func artworkChange(_ report: InAppEventArtworkReport, newLanguage locale: String, of event: InAppEvent, source: ChangeSource) -> PendingChange {
        artworkChange(
            report, localizationID: EventLocalizationPlaceholder(eventID: event.id, locale: locale).token, locale: locale, oldMedia: nil,
            of: event, source: source
        )
    }

    private func artworkChange(
        _ report: InAppEventArtworkReport, localizationID: String, locale: String, oldMedia: InAppEventMedia?, of event: InAppEvent,
        source: ChangeSource
    ) -> PendingChange {
        let push = InAppEventArtworkPush(
            localizationID: localizationID, kind: report.kind, isVideo: report.file.isVideo, fileName: report.file.fileName,
            fileSize: report.file.fileSize, path: report.url.path(percentEncoded: false), previewFrameTimeCode: report.previewFrameTimeCode
        )
        var change = PendingChange(
            id: artworkChangeID(eventID: event.id, kind: report.kind, locale: locale),
            appID: appID, section: .inAppEvents, group: group(event), groupID: event.id,
            title: "\(Self.localeName(locale)) · \(report.kind.title)", flagRegion: Self.region(locale),
            oldValue: Self.mediaValue(oldMedia),
            newValue: "\(report.file.title) · \(report.file.pixelSize.title) · \(report.file.fileName)",
            source: source, requests: [push.request]
        )
        if source.isAssistant {
            change.awaitingAcceptance = String(localized: "Look at it, then accept it here or in In-App Events.")
        }
        return change
    }

    /// The art waiting for `eventID`, by kind then language.
    func queuedArtwork(for eventID: String, in changes: [PendingChange]) -> [InAppEventQueuedArtwork] {
        let prefix = "\(idPrefix)\(eventID).\(Self.artworkSegment)."
        return changes.compactMap { change -> InAppEventQueuedArtwork? in
            guard owns(change), change.id.hasPrefix(prefix) else { return nil }
            let rest = change.id.dropFirst(prefix.count)
            guard let dot = rest.firstIndex(of: "."),
                  let kind = InAppEventMedia.Kind(mcpValue: String(rest[..<dot])),
                  let push = change.requests.lazy.compactMap(InAppEventArtworkPush.init).first
            else { return nil }
            return InAppEventQueuedArtwork(
                changeID: change.id, kind: kind, locale: String(rest[rest.index(after: dot)...]), push: push, source: change.source,
                isAwaitingAcceptance: change.awaitingAcceptance != nil
            )
        }
        .sorted { ($0.kind == .card ? 0 : 1, $0.locale) < ($1.kind == .card ? 0 : 1, $1.locale) }
    }

    /// "Image 1920 × 1080", "Video" or "None".
    static func mediaValue(_ media: InAppEventMedia?) -> String {
        guard let media else { return String(localized: "None") }
        if media.isVideo { return String(localized: "Video") }
        return media.sizeText.map { String(localized: "Image \($0)") } ?? String(localized: "Image")
    }
}
