//
//  EventArtworkStyle.swift
//  Atlas
//

import Foundation

/// Where an event's artwork starts from: a new look Claude draws
/// for the event, one of Atlas's event layouts in the app's colors, or the
/// card the event already has, extended into the missing details image.
enum EventArtworkStyle: String, Codable, CaseIterable, Hashable, Sendable {
    case newLook
    case template
    case extendCard

    var title: String {
        switch self {
        case .newLook: String(localized: "A new look from Claude")
        case .template: String(localized: "Start from a template")
        case .extendCard: String(localized: "Extend the card you have")
        }
    }

    func detail(appName: String) -> String {
        switch self {
        case .newLook: String(localized: "Three concepts drawn for this event, in \(appName)’s brand.")
        case .template: String(localized: "Atlas’s event layouts in your colors: challenge, premiere, live, new season.")
        case .extendCard: String(localized: "Keeps your event card and makes the missing details image to match.")
        }
    }

    /// The kinds of image each concept has: a pair, or only the details
    /// image when the card stays.
    var kinds: [InAppEventMedia.Kind] {
        self == .extendCard ? [.details] : InAppEventMedia.Kind.allCases
    }
}
