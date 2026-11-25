//
//  WatchInputs.swift
//  Atlas
//

import Foundation

/// What Atlas already read about one app by the end of an hourly check,
/// for Look for Improvements' detectors (`WatchDetectors`): nothing here
/// costs another request to App Store Connect.
struct WatchInputs: Hashable, Sendable {
    /// The version on its way to the App Store, or the live one.
    struct Version: Hashable, Sendable {
        var id: String
        var versionString: String
        var phase: ReleasePhase
        /// When this Mac first saw it go out, if it did.
        var liveSince: Date?
    }

    /// The version's What's New, language by language.
    struct WhatsNew: Hashable, Sendable {
        var languages: Int
        /// Locale codes with no What's New and nothing suggested.
        var missing: [String]
        /// Languages whose What's New waits as a suggestion.
        var suggested = 0
    }

    /// The project's commits since its last release tag.
    struct Commits: Hashable, Sendable {
        /// "v1.4"; nil when no tag was found.
        var tag: String?
        var count: Int
    }

    var appID: StoreApp.ID
    var appName: String
    var now: Date
    var stability: StabilityReport?
    var version: Version?
    var whatsNew: WhatsNew?
    /// Read only when What's New is missing; nil without a project folder.
    var commits: Commits?
    var events: [WatchEventFacts] = []
    var reviews: [AppReview] = []
    /// The version the reviews are about now (Reviews' current version).
    var reviewedVersion: String?
    /// The groups an assistant sent before.
    var themes: [ReviewTheme] = []
    /// What the version being prepared still lacks.
    var blockers: [WatchSubmissionBlocker] = []

    init(appID: StoreApp.ID, appName: String, now: Date) {
        self.appID = appID
        self.appName = appName
        self.now = now
    }
}
