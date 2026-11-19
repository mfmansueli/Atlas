//
//  StorePageViewModel+NewVersion.swift
//  Atlas
//

import Foundation

// New Version…: a version to create in App Store Connect, queued as one
// change in Review & Push ("Create version 1.5"). Once it's pushed, the
// Store Page reloads and opens on it, the newest editable version.
extension StorePageViewModel {
    private var newVersionBuilder: NewAppVersionChangeBuilder { NewAppVersionChangeBuilder(appID: app.id) }

    private var versions: [StorePageVersion] { content?.versions ?? [] }

    /// The app's platforms, iOS first: the sheet's choices.
    var newVersionPlatforms: [String] { NewAppVersionRules.platforms(in: versions) }

    /// New Version… is offered: a platform has no version in progress and
    /// none is queued for it yet.
    var canCreateVersion: Bool {
        newVersionPlatforms.contains { NewAppVersionRules.inProgress(on: $0, in: versions) == nil && queuedNewVersion(on: $0) == nil }
    }

    /// The sheet's starting point: the first platform free for one, and
    /// its latest number plus one.
    var newVersionStart: NewAppVersion {
        let free = newVersionPlatforms.first { NewAppVersionRules.inProgress(on: $0, in: versions) == nil && queuedNewVersion(on: $0) == nil }
        let platform = free ?? NewAppVersionRules.defaultPlatform(in: versions) ?? StorePageVersion.iOSPlatform
        return NewAppVersion(versionString: suggestedNewVersionNumber(on: platform), platform: platform)
    }

    func suggestedNewVersionNumber(on platform: String) -> String {
        NewAppVersionRules.suggestedNumber(on: platform, in: versions)
    }

    /// The latest version on `platform`, for the sheet's hint.
    func latestVersion(on platform: String) -> StorePageVersion? {
        NewAppVersionRules.latest(on: platform, in: versions)
    }

    /// Why `version` can't be created, or nil.
    func newVersionProblem(_ version: NewAppVersion) -> NewAppVersionProblem? {
        NewAppVersionRules.problem(for: NewAppVersion(versionString: version.versionString, platform: version.platform), in: versions)
    }

    /// The new versions waiting in Review & Push.
    var queuedNewVersions: [NewAppVersion] {
        newVersionBuilder.queued(in: queue).compactMap(NewAppVersionChangeBuilder.version(of:))
    }

    func queuedNewVersion(on platform: String) -> NewAppVersion? {
        queuedNewVersions.first { $0.platform == platform }
    }

    func openNewVersion() {
        sheet = .newVersion
    }

    /// Add to Review & Push: replaces a version queued for the same
    /// platform. Returns false when App Store Connect wouldn't take it.
    @discardableResult
    func queueNewVersion(_ draft: NewAppVersion) -> Bool {
        let version = NewAppVersion(versionString: draft.versionString, platform: draft.platform)
        guard newVersionProblem(version) == nil else { return false }
        queue.upsert(newVersionBuilder.change(for: version, showsPlatform: newVersionPlatforms.count > 1))
        sheet = nil
        toast = ToastMessage(text: String(localized: "Version \(version.versionString) waits in Review & Push. Once it’s pushed, edit its texts here."))
        return true
    }
}
