//
//  NewAppVersionProblem.swift
//  Atlas
//

import Foundation

/// Why a version can't be created: what the New Version sheet says under
/// its number, and what `propose_app_version` refuses with.
enum NewAppVersionProblem: Hashable, Sendable {
    /// Not one to three whole numbers, e.g. "1.4 beta".
    case malformed
    /// The app has no version on that platform, so App Store Connect
    /// doesn't sell it there yet.
    case unknownPlatform(String)
    /// A version on that platform is still in progress: App Store Connect
    /// has one at a time per platform.
    case inProgress(versionString: String, state: ListingVersionState)
    /// Not higher than the latest version on that platform.
    case notHigher(latest: String)

    var message: String {
        switch self {
        case .malformed:
            String(localized: "Use one to three whole numbers separated by periods, like 1.4 or 2.0.1.")
        case let .unknownPlatform(platform):
            String(localized: "The app has no \(platform) version. Add the platform in App Store Connect first.")
        case let .inProgress(version, state) where state.isEditable:
            String(localized: "Version \(version) is still being prepared. Edit it, or change its number in App Store Connect: there’s one version in progress at a time.")
        case let .inProgress(version, state):
            String(localized: "Version \(version) is \(state.title). A new version can be created once it’s released.")
        case let .notHigher(latest):
            String(localized: "Use a number higher than \(latest), the latest version.")
        }
    }
}
