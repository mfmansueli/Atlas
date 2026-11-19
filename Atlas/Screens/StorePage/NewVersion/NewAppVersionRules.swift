//
//  NewAppVersionRules.swift
//  Atlas
//

import Foundation

/// What App Store Connect allows when creating a version, from the app's
/// versions as the Store Page reads them: one version in progress per
/// platform, each new one numbered higher than the last.
enum NewAppVersionRules {
    /// The app's platforms, iOS first.
    static func platforms(in versions: [StorePageVersion]) -> [String] {
        var seen: Set<String> = []
        let platforms: [String] = versions.compactMap(\.platform).filter { seen.insert($0).inserted }
        let iOS = StorePageVersion.iOSPlatform
        return platforms.filter { $0 == iOS } + platforms.filter { $0 != iOS }
    }

    /// The highest-numbered version on `platform`.
    static func latest(on platform: String, in versions: [StorePageVersion]) -> StorePageVersion? {
        versions.filter { $0.platform == platform }.max { NewAppVersion.isHigher($1.versionString, than: $0.versionString) }
    }

    /// A version on `platform` that isn't on the App Store yet: being
    /// prepared, in review or waiting to be released.
    static func inProgress(on platform: String, in versions: [StorePageVersion]) -> StorePageVersion? {
        versions.first { $0.platform == platform && !$0.state.isLive }
    }

    /// The platform a new version is most likely for: the first without a
    /// version in progress.
    static func defaultPlatform(in versions: [StorePageVersion]) -> String? {
        let platforms = platforms(in: versions)
        return platforms.first { inProgress(on: $0, in: versions) == nil } ?? platforms.first
    }

    /// The number the sheet starts with: the latest one plus one.
    static func suggestedNumber(on platform: String, in versions: [StorePageVersion]) -> String {
        latest(on: platform, in: versions).map { NewAppVersion.next(after: $0.versionString) } ?? "1.0"
    }

    /// Whether any platform can take a new version.
    static func canCreate(in versions: [StorePageVersion]) -> Bool {
        platforms(in: versions).contains { inProgress(on: $0, in: versions) == nil }
    }

    /// Why `version` can't be created, or nil when it can.
    static func problem(for version: NewAppVersion, in versions: [StorePageVersion]) -> NewAppVersionProblem? {
        guard NewAppVersion.isWellFormed(version.versionString) else { return .malformed }
        guard platforms(in: versions).contains(version.platform) else { return .unknownPlatform(version.platformTitle) }
        if let current = inProgress(on: version.platform, in: versions) {
            return .inProgress(versionString: current.versionString, state: current.state)
        }
        if let latest = latest(on: version.platform, in: versions),
           !NewAppVersion.isHigher(version.versionString, than: latest.versionString)
        {
            return .notHigher(latest: latest.versionString)
        }
        return nil
    }
}
