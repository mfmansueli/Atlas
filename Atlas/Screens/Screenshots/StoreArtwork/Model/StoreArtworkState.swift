//
//  StoreArtworkState.swift
//  Atlas
//

import Foundation

/// Where a language's header or search artwork is, in the same pills as
/// the screenshots: on the App Store, new or replaced and waiting in
/// Review & Push (outlined in blue), marked to be deleted, or none.
enum StoreArtworkState: Hashable, Sendable {
    case live
    case new
    case replaced
    case willBeDeleted
    case none

    /// Waits in Review & Push.
    var isPending: Bool {
        switch self {
        case .new, .replaced, .willBeDeleted: true
        case .live, .none: false
        }
    }

    /// New or replaced: the blue outline of what's not pushed.
    var isNotPushed: Bool { self == .new || self == .replaced }

    /// What the App Store shows after the next push: artwork, or nothing
    /// (deleted or none).
    var showsOnStore: Bool {
        switch self {
        case .live, .new, .replaced: true
        case .willBeDeleted, .none: false
        }
    }

    /// "Live", "New · not pushed", "Replaced · not pushed", "Will be
    /// deleted", and for none the place's own words.
    func title(for place: StoreArtworkPlace) -> String {
        switch self {
        case .live: String(localized: "Live", comment: "kind:status")
        case .new: String(localized: "New · not pushed", comment: "kind:status")
        case .replaced: String(localized: "Replaced · not pushed", comment: "kind:status")
        case .willBeDeleted: String(localized: "Will be deleted", comment: "kind:status")
        case .none: place.noneTitle
        }
    }

    var pillStyle: PillStyle {
        switch self {
        case .new, .replaced: .accent
        case .willBeDeleted: .danger
        case .live, .none: .outline
        }
    }
}
