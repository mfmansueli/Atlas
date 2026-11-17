//
//  ReleaseAction.swift
//  Atlas
//

import Foundation

/// A write the version card can ask App Store Connect for, one at a time.
enum ReleaseAction: Hashable, Sendable {
    case cancelSubmission
    case releaseNow
    case pause
    case resume
    case releaseToEveryone
    case submitAgain

    /// The question asked before something that can't be taken back, or
    /// nil when it goes ahead.
    func confirmation(version: String) -> String? {
        switch self {
        case .cancelSubmission: String(localized: "Take \(version) back from App Review?")
        case .releaseNow: String(localized: "Release \(version) on the App Store now?")
        case .releaseToEveryone: String(localized: "Release \(version) to everyone now?")
        case .pause, .resume, .submitAgain: nil
        }
    }

    /// What the confirmation says under its question.
    func consequence(version: String) -> String {
        switch self {
        case .cancelSubmission:
            String(localized: "\(version) goes back to Prepare for Submission. Nothing you edited is lost, and you can submit it again.")
        case .releaseNow:
            String(localized: "People can download \(version) as soon as Apple has processed it. This can’t be undone.")
        case .releaseToEveryone:
            String(localized: "The phased release ends: everyone with automatic updates gets \(version). This can’t be undone.")
        case .pause, .resume, .submitAgain:
            ""
        }
    }

    func confirmTitle(version: String) -> String {
        switch self {
        case .cancelSubmission: String(localized: "Cancel Submission")
        case .releaseNow: String(localized: "Release \(version) Now")
        case .releaseToEveryone: String(localized: "Release to Everyone")
        case .pause: String(localized: "Pause")
        case .resume: String(localized: "Resume")
        case .submitAgain: String(localized: "Submit Again")
        }
    }
}
