//
//  ClaudeCodeRunPurpose.swift
//  Atlas
//

import Foundation

/// What a run started from Atlas is for: it names the run, picks
/// its permissions, and lets each screen find its own run.
enum ClaudeCodeRunPurpose: Hashable, Sendable {
    /// Setup's test, "List my apps in Atlas".
    case test
    /// Ask on a suggestion bar, e.g. "Store Page".
    case ask(area: String)
    case suggestEverything
    case autopilot
    /// Translate Missing on Store Page.
    case translation
    /// Translate captions in Screenshots.
    case captions
    case privacyScan
    /// Ask Claude Code… on an In-App Event's images and video.
    case eventArtwork(eventID: String)
    /// Make the Artwork…: Claude's three concepts for an event.
    case eventArtworkConcepts(eventID: String)

    /// "Suggest Everything", "Ask · Store Page".
    var title: String {
        switch self {
        case .test: String(localized: "Setup test")
        case let .ask(area): String(localized: "Ask · \(area)")
        case .suggestEverything: String(localized: "Suggest Everything")
        case .autopilot: String(localized: "Screenshot Autopilot")
        case .translation: String(localized: "Translate missing languages")
        case .captions: String(localized: "Translate captions")
        case .privacyScan: String(localized: "App Privacy scan")
        case .eventArtwork: String(localized: "Ask · In-App Event art")
        case .eventArtworkConcepts: String(localized: "In-App Event artwork")
        }
    }

    /// What an asking button's request is about, as the toolbar and the
    /// toast say it: "Store Page", "In-App Event art".
    var askSubject: String {
        switch self {
        case let .ask(area): area
        case .eventArtwork: String(localized: "In-App Event art")
        case .test, .suggestEverything, .autopilot, .translation, .captions, .privacyScan, .eventArtworkConcepts: title
        }
    }

    var permissions: ClaudeCodePermissions {
        switch self {
        case .test: .atlasOnly
        case .autopilot: .autopilot
        case .eventArtwork, .eventArtworkConcepts: .eventArtwork
        case .ask, .suggestEverything, .translation, .captions, .privacyScan: .readProject
        }
    }
}
