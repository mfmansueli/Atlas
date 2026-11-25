//
//  StoreArtworkPlace.swift
//  Atlas
//

import Foundation

/// The two places on the App Store where a language can show artwork of
/// its own: the product page header (21:9, at the top of the page) and
/// search results (3:2). Both are optional: without a header the page
/// starts with the icon and name; without search artwork, search shows
/// screenshots 1–3.
enum StoreArtworkPlace: String, Codable, CaseIterable, Hashable, Sendable {
    case header
    case search

    /// The artwork kind made for it.
    var kind: AutopilotArtworkKind {
        switch self {
        case .header: .header
        case .search: .search
        }
    }

    /// App Store Connect's placement type.
    var placementType: String {
        switch self {
        case .header: AutopilotArtworkKind.headerPlacement
        case .search: AutopilotArtworkKind.searchPlacement
        }
    }

    init?(placementType: String) {
        switch placementType {
        case AutopilotArtworkKind.headerPlacement: self = .header
        case AutopilotArtworkKind.searchPlacement: self = .search
        default: return nil
        }
    }

    /// Whether a made file of `kind` shows here: the one 16:9 image is
    /// both.
    func shows(_ kind: AutopilotArtworkKind) -> Bool {
        switch self {
        case .header: kind.isHeader
        case .search: kind.isSearch
        }
    }

    /// "Header", "Search results artwork".
    var title: String {
        switch self {
        case .header: String(localized: "Header", comment: "kind:label")
        case .search: String(localized: "Search results artwork", comment: "kind:label")
        }
    }

    /// "21:9 · top of the product page".
    var spec: String {
        switch self {
        case .header: String(localized: "21:9 · top of the product page", comment: "kind:label")
        case .search: String(localized: "3:2 · in search results", comment: "kind:label")
        }
    }

    /// What a file needs, under Add and Replace.
    var fileRule: String {
        switch self {
        case .header: String(localized: "PNG or JPEG, 3840 × 1646, no transparency", comment: "kind:label")
        case .search: String(localized: "PNG or JPEG, 3:2, up to 3840 × 2560", comment: "kind:label")
        }
    }

    /// "Add Header…", "Add Search Artwork…".
    var addTitle: String {
        switch self {
        case .header: String(localized: "Add Header…", comment: "kind:menu")
        case .search: String(localized: "Add Search Artwork…", comment: "kind:menu")
        }
    }

    /// Under Delete: what the App Store shows once it's gone.
    var deleteNote: String {
        switch self {
        case .header: String(localized: "The page starts with the icon and name", comment: "kind:label")
        case .search: String(localized: "Search shows screenshots 1–3 again", comment: "kind:label")
        }
    }

    /// The pill when there's none.
    var noneTitle: String {
        switch self {
        case .header: String(localized: "None", comment: "kind:status")
        case .search: String(localized: "Uses screenshots 1–3", comment: "kind:status")
        }
    }
}
