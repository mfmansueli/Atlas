//
//  InAppEventBadge.swift
//  Atlas
//

import Foundation

/// The badge on an In-App Event's card: what kind of event it is.
enum InAppEventBadge: String, CaseIterable, Identifiable, Hashable, Sendable {
    case liveEvent = "LIVE_EVENT"
    case premiere = "PREMIERE"
    case challenge = "CHALLENGE"
    case competition = "COMPETITION"
    case newSeason = "NEW_SEASON"
    case majorUpdate = "MAJOR_UPDATE"
    case specialEvent = "SPECIAL_EVENT"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .liveEvent: String(localized: "Live Event")
        case .premiere: String(localized: "Premiere")
        case .challenge: String(localized: "Challenge")
        case .competition: String(localized: "Competition")
        case .newSeason: String(localized: "New Season")
        case .majorUpdate: String(localized: "Major Update")
        case .specialEvent: String(localized: "Special Event")
        }
    }
}
