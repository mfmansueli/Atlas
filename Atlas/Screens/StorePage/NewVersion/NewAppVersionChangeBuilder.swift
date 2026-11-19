//
//  NewAppVersionChangeBuilder.swift
//  Atlas
//

import Foundation

/// Turns a new version into one Review & Push change, "Create version
/// 1.5": a `POST /v1/appStoreVersions` with its number and platform. A push
/// after one that created it finds it (`NewAppStoreVersionCreate`). It
/// restores nothing: a version is deleted in App Store Connect.
///
/// One per platform: queuing another number for the same platform replaces
/// it. Its texts are edited on the Store Page once it's pushed, since App
/// Store Connect gives it its own localizations.
struct NewAppVersionChangeBuilder {
    let appID: StoreApp.ID

    static let idPrefix = "appStoreVersion."
    static let path = "/v1/appStoreVersions"

    /// `appStoreVersion.<appID>.<platform>`.
    func changeID(platform: String) -> PendingChange.ID {
        "\(Self.idPrefix)\(appID).\(platform)"
    }

    func owns(_ change: PendingChange) -> Bool {
        change.appID == appID && change.id.hasPrefix("\(Self.idPrefix)\(appID).")
    }

    /// The app's new versions waiting in Review & Push.
    @MainActor
    func queued(in queue: ChangeQueue) -> [PendingChange] {
        queue.changes(for: appID, section: .storePage).filter(owns)
    }

    /// The version a queued change creates.
    static func version(of change: PendingChange) -> NewAppVersion? {
        guard let body = change.requests.first?.body,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let attributes = (object["data"] as? [String: Any])?["attributes"] as? [String: Any],
              let versionString = attributes["versionString"] as? String,
              let platform = attributes["platform"] as? String
        else { return nil }
        return NewAppVersion(versionString: versionString, platform: platform)
    }

    /// "Create version 1.5", with the platform when the app has several.
    func change(
        for version: NewAppVersion,
        showsPlatform: Bool,
        source: ChangeSource = .you,
        reason: String? = nil,
        at date: Date = .now
    ) -> PendingChange {
        let id = changeID(platform: version.platform)
        let name = showsPlatform
            ? String(localized: "Version \(version.versionString) · \(version.platformTitle)")
            : String(localized: "Version \(version.versionString)")
        var change = PendingChange(
            id: id,
            appID: appID,
            section: .storePage,
            group: String(localized: "Store Page · New version"),
            title: name,
            oldValue: "",
            newValue: String(localized: "Prepare for Submission"),
            source: source,
            requests: [Self.request(for: version, appID: appID)],
            createdAt: date
        )
        let detail = String(localized: "A new \(version.platformTitle) version in Prepare for Submission. Once it’s pushed, edit its texts on the Store Page.")
        change.creation = PendingCreation(
            id: id,
            title: String(localized: "Create version \(version.versionString)"),
            detail: [detail, reason].compactMap(\.self).filter { !$0.isEmpty }.joined(separator: " "),
            source: source,
            fields: []
        )
        return change
    }

    static func request(for version: NewAppVersion, appID: StoreApp.ID) -> PushRequest {
        let body: [String: Any] = [
            "data": [
                "type": "appStoreVersions",
                "attributes": ["platform": version.platform, "versionString": version.versionString],
                "relationships": ["app": ["data": ["type": "apps", "id": appID]]],
            ],
        ]
        let data = (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return PushRequest(method: .post, path: path, body: data)
    }
}
