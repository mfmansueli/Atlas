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
    /// Check in the Code: whether the app opens an event's deep link.
    case deepLinkCheck(eventID: String)
    /// Make It Work…: the app opens an event's deep link.
    case deepLinkWork(eventID: String)
    /// Make Screenshots for This Page…: a custom product page's own set.
    case pageScreenshots(pageName: String)

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
        case .deepLinkCheck: String(localized: "Check an event’s deep link")
        case .deepLinkWork: String(localized: "Make an event’s deep link work")
        case let .pageScreenshots(pageName): String(localized: "Screenshots for “\(pageName)”")
        }
    }

    /// What an asking button's request is about, as the toolbar and the
    /// toast say it: "Store Page", "In-App Event art".
    var askSubject: String {
        switch self {
        case let .ask(area): area
        case .eventArtwork: String(localized: "In-App Event art")
        case .deepLinkCheck, .deepLinkWork: String(localized: "In-App Event deep link")
        case .pageScreenshots: String(localized: "Product page screenshots")
        case .test, .suggestEverything, .autopilot, .translation, .captions, .privacyScan, .eventArtworkConcepts: title
        }
    }

    var permissions: ClaudeCodePermissions {
        switch self {
        case .test: .atlasOnly
        case .autopilot: .autopilot
        case .eventArtwork, .eventArtworkConcepts: .eventArtwork
        case .deepLinkCheck: .deepLinkCheck
        case .deepLinkWork: .deepLinkWork
        case .ask, .suggestEverything, .translation, .captions, .privacyScan, .pageScreenshots: .readProject
        }
    }
}
