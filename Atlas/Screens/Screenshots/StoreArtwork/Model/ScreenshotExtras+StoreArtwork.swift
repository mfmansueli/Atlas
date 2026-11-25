//
//  ScreenshotExtras+StoreArtwork.swift
//  Atlas
//

import Foundation

/// Header and search artwork changed by hand on the Screenshots page: a
/// file given in place of what's live, or what's live marked to be
/// deleted. Both wait in Review & Push with Autopilot's files, and a push
/// notes them like those.
extension ScreenshotExtras {
    /// The set a language's first hand-given file starts when no Autopilot
    /// run made one.
    static func byHand(at date: Date) -> ScreenshotExtras {
        ScreenshotExtras(directionName: String(localized: "By hand", comment: "kind:label"), madeAt: date)
    }

    /// Whether `file` still waits: not on App Store Connect yet and not
    /// discarded.
    func waits(_ file: ExtrasArtworkFile) -> Bool {
        pushedChecksums?[file.id] != file.fileID && discardedChecksums?[file.id] != file.fileID
    }

    /// The file waiting to go to `place` in `locale`: the place's own,
    /// else the 16:9 one that's both.
    func pendingArtwork(_ place: StoreArtworkPlace, locale: String) -> ExtrasArtworkFile? {
        let waiting = artwork.filter { $0.locale == locale && place.shows($0.kind) && waits($0) }
        return waiting.first { $0.kind == place.kind } ?? waiting.first
    }

    /// The place marked to be deleted in `locale`, if it is.
    func removal(_ place: StoreArtworkPlace, locale: String) -> ExtrasArtworkRemoval? {
        artworkRemovals?.first { $0.place == place && $0.locale == locale }
    }

    /// Puts a file given by hand in its place: it replaces the place's
    /// own file in that language and any deletion marked there.
    mutating func setHandArtwork(_ file: ExtrasArtworkFile) {
        artwork.removeAll { $0.locale == file.locale && $0.kind == file.kind }
        artwork.append(file)
        dropRemoval(file.kind == .header ? .header : .search, locale: file.locale)
        if var discarded = discardedChecksums {
            discarded[file.id] = nil
            discardedChecksums = discarded.isEmpty ? nil : discarded
        }
        coverArtworkKinds()
    }

    /// Delete…: what's live comes off with the next push; a file waiting
    /// there leaves.
    mutating func markRemoval(_ place: StoreArtworkPlace, locale: String, at date: Date) {
        dropPendingFile(place, locale: locale)
        guard removal(place, locale: locale) == nil else { return }
        artworkRemovals = (artworkRemovals ?? []) + [ExtrasArtworkRemoval(place: place, locale: locale, markedAt: date)]
    }

    /// Delete… on a file that isn't live yet, or Undo Change: back to
    /// what's on the App Store.
    mutating func undoArtworkChange(_ place: StoreArtworkPlace, locale: String) {
        dropRemoval(place, locale: locale)
        dropPendingFile(place, locale: locale)
    }

    /// Notes a pushed item: a deletion is done, a file is what App Store
    /// Connect has.
    mutating func notePushed(_ itemID: String, fileID: String) {
        if let removal = artworkRemovals?.first(where: { $0.id == itemID }) {
            dropRemoval(removal.place, locale: removal.locale)
            return
        }
        var pushed = pushedChecksums ?? [:]
        pushed[itemID] = fileID
        pushedChecksums = pushed
    }

    /// The place's waiting file leaves: one given by hand goes, one
    /// Autopilot made is discarded (it stays in the set, off the App
    /// Store, as Discard in Review & Push leaves it).
    private mutating func dropPendingFile(_ place: StoreArtworkPlace, locale: String) {
        guard let file = pendingArtwork(place, locale: locale) else { return }
        if file.byHand != nil {
            artwork.removeAll { $0.id == file.id }
        } else {
            var discarded = discardedChecksums ?? [:]
            discarded[file.id] = file.fileID
            discardedChecksums = discarded
        }
    }

    private mutating func dropRemoval(_ place: StoreArtworkPlace, locale: String) {
        artworkRemovals?.removeAll { $0.place == place && $0.locale == locale }
        if artworkRemovals?.isEmpty == true { artworkRemovals = nil }
    }

    /// Widens `artworkSize` to the kinds the set now has, so its artwork
    /// counts (`hasArtwork`). It never narrows what a run made.
    private mutating func coverArtworkKinds() {
        let kinds = Set(artwork.map(\.kind))
        if kinds.contains(.wide), artworkSize == nil { artworkSize = .wide }
        let header = kinds.contains(.header) || artworkSize?.headerKind == .header
        let search = kinds.contains(.search) || artworkSize?.searchKind == .search
        guard artworkSize != .wide else { return }
        switch (header, search) {
        case (true, true): artworkSize = .headerAndSearch
        case (true, false): artworkSize = .headerOnly
        case (false, true): artworkSize = .searchOnly
        case (false, false): break
        }
    }
}
