//
//  VersionStatusSummary.swift
//  Atlas
//

import Foundation

/// The version's status in a line, for the sidebar's footer and the
/// toolbar's title: "Version 1.4 · Not submitted yet", with the one thing
/// to do when there is one.
struct VersionStatusSummary: Hashable, Sendable {
    /// The dot's color.
    enum Tone: Hashable, Sendable {
        case neutral
        case active
        case good
        case warning
        case bad
    }

    var versionString: String
    var text: String
    var tone: Tone
    /// "Submit…", "Release…" or "Fix…".
    var actionTitle: String?
    /// The footer opens the Submit sheet rather than Overview.
    var opensSubmit = false

    init(versionString: String, phase: ReleasePhase) {
        self.versionString = versionString
        switch phase {
        case .prepare:
            text = String(localized: "Not submitted yet")
            tone = .neutral
            actionTitle = String(localized: "Submit…")
            opensSubmit = true
        case .waitingForReview:
            text = String(localized: "Waiting for Review")
            tone = .active
        case .inReview:
            text = String(localized: "In Review")
            tone = .active
        case .rejected:
            text = String(localized: "Rejected by App Review")
            tone = .bad
            actionTitle = String(localized: "Fix…")
        case .pendingDeveloperRelease:
            text = String(localized: "Approved · ready to release")
            tone = .good
            actionTitle = String(localized: "Release…")
        case .pendingAppleRelease:
            text = String(localized: "Approved · Apple releases it")
            tone = .good
        case let .phased(day, isPaused):
            text = isPaused ? String(localized: "Phased Release paused") : String(localized: "Rolling out · day \(day) of \(PhasedRelease.dayCount)")
            tone = isPaused ? .warning : .good
        case .live:
            text = String(localized: "On the App Store")
            tone = .good
        }
    }

    /// Before the status is read: what the Store Page's summary knows.
    init?(storePage: StorePageSummary?) {
        guard let versionString = storePage?.versionString else { return nil }
        self.versionString = versionString
        text = storePage?.versionState ?? ""
        tone = .neutral
    }

    /// "Version 1.4".
    var title: String {
        String(localized: "Version \(versionString)")
    }

    /// "Version 1.4 · Not submitted yet", under the app's name.
    var line: String {
        text.isEmpty ? title : "\(title) · \(text)"
    }

    /// "Version 1.4, Not submitted yet", for VoiceOver.
    var accessibilityText: String {
        text.isEmpty ? title : "\(title), \(text)"
    }
}
