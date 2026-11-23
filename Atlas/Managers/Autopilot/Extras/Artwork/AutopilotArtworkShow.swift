//
//  AutopilotArtworkShow.swift
//  Atlas
//

import Foundation

/// What the search results artwork shows beside its headline. The header
/// never shows a device; one 16:9 image follows the same choice.
enum AutopilotArtworkShow: String, Codable, CaseIterable, Hashable, Sendable {
    /// One real screen from the captures, in a phone.
    case phone
    /// The same real screen, cropped, rounded and floating, with no phone.
    case ui
    /// Only the name, the headline and a scene in the brand's style: no
    /// captures needed for the artwork.
    case scene

    var title: String {
        switch self {
        case .phone: String(localized: "A phone with the app")
        case .ui: String(localized: "The app, no device")
        case .scene: String(localized: "No app: a scene")
        }
    }

    /// The plan's note under the choice.
    var note: String {
        switch self {
        case .phone: String(localized: "A real screen in a phone. Apple advises showing the app in search.")
        case .ui: String(localized: "The same screen, cropped and floating, no phone. Still shows the app, lighter.")
        case .scene: String(localized: """
            Only name, headline and a brand-style scene; no captures needed. Best when the look says more than the \
            screens.
            """)
        }
    }

    /// The artwork needs captures.
    var needsCaptures: Bool { self != .scene }
}
