//
//  StoreArtworkFixtures.swift
//  AtlasTests
//

#if DEBUG
import Foundation
@testable import Atlas

/// Board 78's pieces for the tests: a live header or search image, and a
/// file given by hand.
enum StoreArtworkFixtures {
    static let date = Date(timeIntervalSince1970: 1_800_000_000)

    static func live(_ place: StoreArtworkPlace, _ locale: String = "de-DE", group: String? = "IPHONE") -> LiveArtworkImage {
        LiveArtworkImage(
            placementID: "pl-\(place.rawValue)-\(locale)-\(group ?? "none")", placementType: place.placementType, placementGroup: group,
            templateURL: "https://is1.mzstatic.com/\(place.rawValue)/{w}x{h}bb.{f}", pixelSize: place.kind.pixelSize
        )
    }

    static func liveSet(header: [String] = [], search: [String] = []) -> LiveStoreArtworkSet {
        var set = LiveStoreArtworkSet()
        for locale in Set(header + search) {
            set.byLocale[locale] = LiveStoreArtwork(
                header: header.contains(locale) ? live(.header, locale) : nil,
                search: search.contains(locale) ? live(.search, locale) : nil
            )
        }
        return set
    }

    static func handFile(_ place: StoreArtworkPlace, _ locale: String = "de-DE", fileID: String = "hand-sum") -> ExtrasArtworkFile {
        ExtrasArtworkFile(
            kind: place.kind, locale: locale, fileID: fileID, headline: "", fits: true, byteCount: 1000, checks: [],
            byHand: ExtrasArtworkHandFile(fileName: "\(place.rawValue).png", pixelSize: place.kind.pixelSize, addedAt: date)
        )
    }

    /// Autopilot's file, as Localize saves it.
    static func madeFile(_ place: StoreArtworkPlace, _ locale: String = "de-DE", fileID: String = "made-sum") -> ExtrasArtworkFile {
        ExtrasArtworkFile(kind: place.kind, locale: locale, fileID: fileID, headline: "Journal in seconds", fits: true, byteCount: 1000, checks: [])
    }

    static func extras(_ files: [ExtrasArtworkFile] = []) -> ScreenshotExtras {
        var extras = ScreenshotExtras.byHand(at: date)
        for file in files { extras.setHandArtwork(file) }
        return extras
    }
}
#endif
