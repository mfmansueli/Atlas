//
//  QueuedAppVersion.swift
//  Atlas
//

import Foundation

/// A new App Store version waiting in Review & Push ("Create version 1.2"),
/// as the version being prepared before App Store Connect has it: its
/// texts start from the version before it, can change, and are queued
/// tied to it. Their requests name it, its localizations and its App
/// Review details with placeholders (`QueuedVersionPlaceholder`) that the
/// push fills in once it's created; discarding it discards them.
struct QueuedAppVersion: Hashable, Sendable {
    var appID: StoreApp.ID
    var version: NewAppVersion
    /// The queued change that creates it.
    var changeID: PendingChange.ID
    /// Its Review & Push heading and row, which its texts join.
    var group: String
    var creationTitle: String

    var versionString: String { version.versionString }
    var platform: String { version.platform }

    /// The app's new versions in `queue`.
    @MainActor
    static func all(for appID: StoreApp.ID, in queue: ChangeQueue) -> [QueuedAppVersion] {
        NewAppVersionChangeBuilder(appID: appID).queued(in: queue).compactMap { QueuedAppVersion(change: $0) }
    }

    init?(change: PendingChange) {
        guard let version = NewAppVersionChangeBuilder.version(of: change) else { return nil }
        appID = change.appID
        self.version = version
        changeID = change.id
        group = change.group
        creationTitle = change.creation?.title ?? change.title
    }

    // MARK: - Placeholders

    /// Its `appStoreVersions` ID.
    var versionToken: String { QueuedVersionPlaceholder(kind: .version, platform: platform, versionString: versionString).token }

    /// Its localization of `locale`, which App Store Connect copies from the
    /// version before.
    func localizationToken(_ locale: StoreLocale) -> String {
        QueuedVersionPlaceholder(kind: .localization(locale.code), platform: platform, versionString: versionString).token
    }

    /// Its `appStoreReviewDetails`, made when it has none.
    var reviewDetailToken: String {
        QueuedVersionPlaceholder(kind: .reviewDetail, platform: platform, versionString: versionString).token
    }

    /// The app info App Store Connect makes with it: name, subtitle, privacy
    /// URLs and categories change there, not in the live one.
    var appInfoToken: String { QueuedVersionPlaceholder(kind: .appInfo, platform: platform, versionString: versionString).token }

    /// That app info's localization of `locale`.
    func appInfoLocalizationToken(_ locale: StoreLocale) -> String {
        QueuedVersionPlaceholder(kind: .appInfoLocalization(locale.code), platform: platform, versionString: versionString).token
    }

    /// That app info's age rating declaration.
    var ageRatingToken: String { QueuedVersionPlaceholder(kind: .ageRating, platform: platform, versionString: versionString).token }

    /// The version as the Store Page and App Information show it: editable,
    /// in Prepare for Submission, under its placeholder ID.
    var storePageVersion: StorePageVersion {
        StorePageVersion(
            id: versionToken,
            listingVersion: ListingVersion(versionString, state: .prepareForSubmission),
            platform: platform,
            createdDate: nil
        )
    }

    // MARK: - Tying changes

    /// Whether `change` writes into this version.
    func isTied(_ change: PendingChange) -> Bool {
        change.appID == appID && change.dependsOn == changeID
    }

    /// `change` waiting with this version: one of its row's fields in
    /// Review & Push, pushed after it and discarded with it. Nothing to
    /// check for a conflict or restore: the version doesn't exist yet. A
    /// change that doesn't write into it is returned as is.
    func tie(_ change: PendingChange) -> PendingChange {
        guard mentions(change) else { return change }
        var tied = change
        tied.section = .storePage
        tied.group = group
        tied.groupID = nil
        tied.dependsOn = changeID
        tied.conflictCheck = nil
        tied.restoreRequests = []
        tied.creation = PendingCreation(
            id: changeID,
            title: creationTitle,
            detail: String(localized: "New \(version.platformTitle) version in Prepare for Submission. The texts below go in once it’s created."),
            source: change.source,
            fields: [PendingChangePart(id: change.id, title: change.title, oldValue: change.oldValue, newValue: change.newValue, source: change.source)]
        )
        return tied
    }

    /// Whether a request of `change` (or its conflict check) names this
    /// version or something of it.
    func mentions(_ change: PendingChange) -> Bool {
        let named = change.requests.flatMap { QueuedVersionPlaceholder.all(in: $0) }
            + QueuedVersionPlaceholder.all(in: change.conflictCheck?.path ?? "")
        return named.contains { $0.platform == platform && $0.versionString == versionString }
    }
}
