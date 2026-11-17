//
//  AutopilotArtworkKind.swift
//  Atlas
//

import Foundation

/// One artwork image Apple places on the App Store, at the size Autopilot
/// makes it (Apple's "Creative assets specifications"): the product page
/// header (21:9), the search results image (3:2, 1920 × 1280 up to 3840 ×
/// 2560), or one 16:9 image for both. PNG, no alpha channel.
///
/// An In-App Event's card (16:9) and details page (9:16) render the same
/// way, at the largest size Apple takes (In-App Event media
/// specifications: 1920 × 1080 up to 3840 × 2160, and turned). Autopilot
/// runs never make them; `render_event_artwork` does.
enum AutopilotArtworkKind: String, Codable, CaseIterable, Hashable, Sendable {
    case header
    case search
    case wide
    case eventCard
    case eventDetails

    var pixelSize: PixelSize {
        switch self {
        case .header: PixelSize(width: 3840, height: 1646)
        case .search: PixelSize(width: 3840, height: 2560)
        case .wide: PixelSize(width: 5244, height: 2950)
        case .eventCard: PixelSize(width: 3840, height: 2160)
        case .eventDetails: PixelSize(width: 2160, height: 3840)
        }
    }

    /// "21:9".
    var ratioTitle: String {
        switch self {
        case .header: "21:9"
        case .search: "3:2"
        case .wide, .eventCard: "16:9"
        case .eventDetails: "9:16"
        }
    }

    /// "Header", "Search results", "Header and search".
    var title: String {
        switch self {
        case .header: String(localized: "Header")
        case .search: String(localized: "Search results")
        case .wide: String(localized: "Header and search")
        case .eventCard: String(localized: "Event card")
        case .eventDetails: String(localized: "Event details page")
        }
    }

    /// The places App Store Connect's Asset Library puts it.
    var placementTypes: [String] {
        switch self {
        case .header: [Self.headerPlacement]
        case .search: [Self.searchPlacement]
        case .wide: [Self.headerPlacement, Self.searchPlacement]
        case .eventCard, .eventDetails: []
        }
    }

    static let headerPlacement = "PRODUCT_PAGE_HEADER_ASSET"
    static let searchPlacement = "APP_STORE_SEARCH_RESULTS_ASSET"

    /// The header's own image, or the 16:9 one that is also the header.
    var isHeader: Bool { self == .header || self == .wide }

    /// The search results image, or the 16:9 one that is also it.
    var isSearch: Bool { self == .search || self == .wide }

    /// An In-App Event's card or details page, not product page artwork.
    var isEvent: Bool { self == .eventCard || self == .eventDetails }

    /// The product page's artwork kinds, the ones Autopilot makes.
    static let storeArtwork: [AutopilotArtworkKind] = [.header, .search, .wide]
}
