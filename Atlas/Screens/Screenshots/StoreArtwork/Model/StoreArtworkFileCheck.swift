//
//  StoreArtworkFileCheck.swift
//  Atlas
//

import Foundation

/// Whether a chosen file can be a header or search image: a PNG or JPEG,
/// 3840 × 1646 for the header, 3:2 up to 3840 × 2560 for search, with no
/// transparency.
enum StoreArtworkFileCheck: Hashable, Sendable {
    case fits
    case unreadable
    case wrongSize(PixelSize)
    case transparent

    /// The narrowest search image Atlas takes: smaller ones look soft on
    /// the App Store.
    static let smallestSearchWidth = 1200

    init(_ file: ScreenshotHandChosenFile, place: StoreArtworkPlace) {
        guard let size = file.pixelSize else {
            self = .unreadable
            return
        }
        if !Self.accepts(size, place: place) {
            self = .wrongSize(size)
        } else if file.hasTransparency {
            self = .transparent
        } else {
            self = .fits
        }
    }

    static func accepts(_ size: PixelSize, place: StoreArtworkPlace) -> Bool {
        switch place {
        case .header:
            return size == AutopilotArtworkKind.header.pixelSize
        case .search:
            let largest = AutopilotArtworkKind.search.pixelSize
            // 3:2 to within a pixel either way.
            let isThreeByTwo = abs(size.width * 2 - size.height * 3) <= 3
            return isThreeByTwo && size.width <= largest.width && size.width >= smallestSearchWidth
        }
    }

    var fits: Bool { self == .fits }

    /// What's wrong and how to fix it; nil when it fits.
    func problem(fileName: String, place: StoreArtworkPlace) -> String? {
        switch self {
        case .fits:
            return nil
        case .unreadable:
            return String(localized: "“\(fileName)” isn’t a PNG or JPEG image Atlas can read.", comment: "kind:error")
        case let .wrongSize(size):
            let shown = size.title
            return switch place {
            case .header:
                String(localized: "\(shown) isn’t a header size. Use 3840 × 1646.", comment: "kind:error")
            case .search:
                String(localized: "\(shown) isn’t a search size. Use 3:2, up to 3840 × 2560.", comment: "kind:error")
            }
        case .transparent:
            return String(
                localized: "“\(fileName)” has transparency, which App Store Connect refuses. Save it without an alpha channel.",
                comment: "kind:error"
            )
        }
    }
}
