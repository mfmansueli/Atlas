//
//  InAppEventArtworkCopies.swift
//  Atlas
//

import Foundation

/// Which art for an event's other languages is the primary language's over
/// again. Apple shows the primary language's card and details page in a
/// language without its own, so a copy there only uploads the same file
/// once more (one video once went into 13 languages, 78 uploads); it's
/// needed only where the language has its own in App Store Connect to
/// replace.
///
/// The primary language's art is what it shows after the push: what's
/// proposed for it now, else what's queued for it, else App Store
/// Connect's.
struct InAppEventArtworkCopies: Sendable {
    let event: InAppEvent
    let primaryLocale: String?
    let primary: [InAppEventMedia.Kind: InAppEventArtworkFingerprint]

    /// `infos` are the queued files' infos by path; `stored` the files kept
    /// for the app, to know App Store Connect's media by name and size;
    /// `proposed` the primary language's art being proposed now.
    init(
        event: InAppEvent, queued: [InAppEventQueuedArtwork], infos: [String: InAppEventArtworkFileInfo] = [:],
        stored: [InAppEventArtworkStoredFile] = [], proposed: [InAppEventMedia.Kind: InAppEventArtworkFingerprint] = [:]
    ) {
        self.event = event
        let primaryLocale = event.primaryLocalization?.locale
        self.primaryLocale = primaryLocale
        var primary: [InAppEventMedia.Kind: InAppEventArtworkFingerprint] = [:]
        for kind in InAppEventMedia.Kind.allCases {
            if let art = proposed[kind] {
                primary[kind] = art
            } else if let art = queued.first(where: { $0.kind == kind && $0.locale == primaryLocale }) {
                primary[kind] = InAppEventArtworkFingerprint(art.push, info: infos[art.push.path])
            } else if let media = event.primaryLocalization?.media.first(where: { $0.kind == kind }) {
                primary[kind] = InAppEventArtworkFingerprint(media, stored: stored)
            }
        }
        self.primary = primary
    }

    /// `file` is the primary language's `kind`.
    func isPrimaryArt(_ file: InAppEventArtworkFingerprint, kind: InAppEventMedia.Kind) -> Bool {
        primary[kind]?.isSameFile(as: file) ?? false
    }

    /// `locale` has its own `kind` in App Store Connect: without new art it
    /// keeps showing that one, not the primary language's.
    func hasOwn(_ kind: InAppEventMedia.Kind, locale: String) -> Bool {
        event.localization(locale)?.media.contains { $0.kind == kind } ?? false
    }

    /// `file` as `locale`'s `kind` is a copy of the primary language's art.
    func isCopy(_ file: InAppEventArtworkFingerprint, kind: InAppEventMedia.Kind, locale: String) -> Bool {
        locale != primaryLocale && isPrimaryArt(file, kind: kind)
    }

    /// A copy the language doesn't need: it shows the primary language's
    /// art without it.
    func isUnneededCopy(_ file: InAppEventArtworkFingerprint, kind: InAppEventMedia.Kind, locale: String) -> Bool {
        isCopy(file, kind: kind, locale: locale) && !hasOwn(kind, locale: locale)
    }

    /// Art other than the primary language's waits for `locale`'s `kind`:
    /// a copy replaces it, so the language shows what the others do.
    func othersWait(_ kind: InAppEventMedia.Kind, locale: String, in queued: [InAppEventQueuedArtwork], infos: [String: InAppEventArtworkFileInfo]) -> Bool {
        queued.contains { art in
            art.kind == kind && art.locale == locale && !isPrimaryArt(InAppEventArtworkFingerprint(art.push, info: infos[art.push.path]), kind: kind)
        }
    }

    /// Whether `file` goes into the queue as `locale`'s `kind`: not when
    /// the language shows it without (a copy of the primary language's art
    /// in a language with none of its own and nothing else waiting).
    func needsQueuing(
        _ file: InAppEventArtworkFingerprint, kind: InAppEventMedia.Kind, locale: String, queued: [InAppEventQueuedArtwork],
        infos: [String: InAppEventArtworkFileInfo]
    ) -> Bool {
        !isUnneededCopy(file, kind: kind, locale: locale) || othersWait(kind, locale: locale, in: queued, infos: infos)
    }

    /// The queued uploads that copy the primary language's art into a
    /// language that shows it anyway: the ones the person can take out.
    func unneededCopies(in queued: [InAppEventQueuedArtwork], infos: [String: InAppEventArtworkFileInfo]) -> [InAppEventQueuedArtwork] {
        queued.filter { isUnneededCopy(InAppEventArtworkFingerprint($0.push, info: infos[$0.push.path]), kind: $0.kind, locale: $0.locale) }
    }
}
