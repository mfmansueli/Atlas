//
//  QueuedVersionPushState.swift
//  Atlas
//

import Foundation

/// Fills in a new version's placeholders (`QueuedVersionPlaceholder`) in
/// its texts' requests: the version this push created, or one an earlier
/// push did (looked up by number and platform); its localizations, which
/// App Store Connect copied from the version before; its App Review
/// details, made with the first one's fields when it has none; and the app
/// info being prepared with it (name, subtitle, privacy URLs, categories,
/// age rating), its localizations and age rating declaration. Each is read
/// once per push.
@MainActor
final class QueuedVersionPushState {
    /// Where the version stands in this push.
    enum Made: Equatable {
        /// Created: its ID.
        case made(String)
        /// In this push and not created (it failed, or wasn't sent).
        case notMade
        /// Not in this push: an earlier one may have created it.
        case notInPush
    }

    /// Each version's ID, by `appID|platform|versionString`.
    private var versionIDs: [String: String] = [:]
    /// Each version's localizations, by locale code.
    private var localizations: [String: [String: String]] = [:]
    /// Each version's App Review details, once read or made; nil when it
    /// has none.
    private var reviewDetails: [String: String?] = [:]
    /// The app info being prepared, by app.
    private var appInfos: [StoreApp.ID: String] = [:]
    /// Each app info's localizations, by locale code.
    private var appInfoLocalizations: [String: [String: String]] = [:]
    /// Each app info's age rating declaration.
    private var ageRatings: [String: String] = [:]

    /// The app info states App Store Connect lets name and subtitle change
    /// in: the one made with a version that isn't live yet.
    static let editableAppInfoStates: Set = ["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "WAITING_FOR_REVIEW"]

    func reset() {
        versionIDs = [:]
        localizations = [:]
        reviewDetails = [:]
        appInfos = [:]
        appInfoLocalizations = [:]
        ageRatings = [:]
    }

    /// `request` with every placeholder filled in. For the first App Review
    /// field of a version without App Review details, a `POST` that makes
    /// them, and the version's ID: pass the ID App Store Connect gave them
    /// to `noteReviewDetail` so the next fields write into them.
    func resolving(
        _ request: PushRequest,
        appID: StoreApp.ID,
        made: (QueuedVersionPlaceholder) -> Made,
        transport: any PushTransport,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> (request: PushRequest, makesReviewDetailFor: String?) {
        var request = request
        while let placeholder = QueuedVersionPlaceholder.all(in: request).first {
            let versionID = try await versionID(of: placeholder, appID: appID, made: made(placeholder), transport: transport, note: note)
            switch placeholder.kind {
            case .version:
                request = request.replacing(placeholder.token, with: versionID)
            case let .localization(locale):
                let id = try await localizationID(locale, versionID: versionID, placeholder: placeholder, transport: transport, note: note)
                request = request.replacing(placeholder.token, with: id)
            case .appInfo, .appInfoLocalization, .ageRating:
                let id = try await appInfoResourceID(placeholder, appID: appID, transport: transport, note: note)
                request = request.replacing(placeholder.token, with: id)
            case .reviewDetail:
                if let id = try await reviewDetailID(versionID: versionID, transport: transport, note: note) {
                    request = request.replacing(placeholder.token, with: id)
                } else {
                    return (Self.reviewDetailCreate(from: request, versionID: versionID), versionID)
                }
            }
        }
        return (request, nil)
    }

    /// The App Review details a `POST` from `resolving` made.
    func noteReviewDetail(_ id: String, versionID: String) {
        reviewDetails[versionID] = id
    }

    // MARK: - The version

    private func versionID(
        of placeholder: QueuedVersionPlaceholder,
        appID: StoreApp.ID,
        made: Made,
        transport: any PushTransport,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> String {
        let key = "\(appID)|\(placeholder.platform)|\(placeholder.versionString)"
        if let known = versionIDs[key] { return known }
        let id: String
        switch made {
        case let .made(made):
            id = made
        case .notMade:
            throw QueuedVersionPlaceholder.NotCreated(versionString: placeholder.versionString)
        case .notInPush:
            let version = NewAppVersion(versionString: placeholder.versionString, platform: placeholder.platform)
            guard let create = NewAppStoreVersionCreate(NewAppVersionChangeBuilder.request(for: version, appID: appID)) else {
                throw QueuedVersionPlaceholder.NotCreated(versionString: placeholder.versionString)
            }
            let response = try await transport.fetch(create.lookupPath)
            note(response.rateLimit)
            guard let found = create.versionID(in: response.data) else {
                throw QueuedVersionPlaceholder.NotCreated(versionString: placeholder.versionString)
            }
            id = found
        }
        versionIDs[key] = id
        return id
    }

    // MARK: - Its localizations

    private func localizationID(
        _ locale: String,
        versionID: String,
        placeholder: QueuedVersionPlaceholder,
        transport: any PushTransport,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> String {
        if localizations[versionID]?[locale] == nil {
            localizations[versionID] = try await Self.localizationIDs(versionID: versionID, transport: transport, note: note)
        }
        guard let id = localizations[versionID]?[locale] else {
            throw QueuedVersionPlaceholder.MissingLocalization(locale: locale, versionString: placeholder.versionString)
        }
        return id
    }

    private static func localizationIDs(
        versionID: String,
        transport: any PushTransport,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> [String: String] {
        let path = "/v1/appStoreVersions/\(versionID)/appStoreVersionLocalizations?fields%5BappStoreVersionLocalizations%5D=locale&limit=50"
        return try await localeIDs(from: path, transport: transport, note: note)
    }

    /// Every resource's ID by its `locale`, following pages from `path`.
    private static func localeIDs(
        from path: String,
        transport: any PushTransport,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> [String: String] {
        var next: String? = path
        var ids: [String: String] = [:]
        while let page = next {
            let response = try await transport.fetch(page)
            note(response.rateLimit)
            let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            for resource in object?["data"] as? [[String: Any]] ?? [] {
                guard let id = resource["id"] as? String,
                      let locale = (resource["attributes"] as? [String: Any])?["locale"] as? String
                else { continue }
                ids[locale] = id
            }
            next = (object?["links"] as? [String: Any])?["next"] as? String
        }
        return ids
    }

    // MARK: - Its app info

    /// The app info being prepared with the version (made with it, or
    /// already there for another platform's), or its localization or age
    /// rating declaration. Without one being prepared, the live one: App
    /// Store Connect then takes what can change there and says what can't.
    private func appInfoResourceID(
        _ placeholder: QueuedVersionPlaceholder,
        appID: StoreApp.ID,
        transport: any PushTransport,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> String {
        let infoID = try await appInfoID(appID: appID, placeholder: placeholder, transport: transport, note: note)
        switch placeholder.kind {
        case let .appInfoLocalization(locale):
            if appInfoLocalizations[infoID]?[locale] == nil {
                let path = "/v1/appInfos/\(infoID)/appInfoLocalizations?fields%5BappInfoLocalizations%5D=locale&limit=50"
                appInfoLocalizations[infoID] = try await Self.localeIDs(from: path, transport: transport, note: note)
            }
            guard let id = appInfoLocalizations[infoID]?[locale] else {
                throw QueuedVersionPlaceholder.MissingLocalization(locale: locale, versionString: placeholder.versionString)
            }
            return id
        case .ageRating:
            if let known = ageRatings[infoID] { return known }
            let response = try await transport.fetch("/v1/appInfos/\(infoID)/ageRatingDeclaration")
            note(response.rateLimit)
            let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            guard let id = (object?["data"] as? [String: Any])?["id"] as? String else {
                throw QueuedVersionPlaceholder.NoAppInfo(versionString: placeholder.versionString)
            }
            ageRatings[infoID] = id
            return id
        default:
            return infoID
        }
    }

    private func appInfoID(
        appID: StoreApp.ID,
        placeholder: QueuedVersionPlaceholder,
        transport: any PushTransport,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> String {
        if let known = appInfos[appID] { return known }
        let response = try await transport.fetch("/v1/apps/\(appID)/appInfos?fields%5BappInfos%5D=state&limit=50")
        note(response.rateLimit)
        let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
        let infos: [(id: String, state: String)] = (object?["data"] as? [[String: Any]] ?? []).compactMap { resource in
            guard let id = resource["id"] as? String else { return nil }
            return (id, (resource["attributes"] as? [String: Any])?["state"] as? String ?? "")
        }
        guard let id = infos.first(where: { Self.editableAppInfoStates.contains($0.state) })?.id
            ?? infos.first(where: { $0.state == "READY_FOR_DISTRIBUTION" })?.id
        else { throw QueuedVersionPlaceholder.NoAppInfo(versionString: placeholder.versionString) }
        appInfos[appID] = id
        return id
    }

    // MARK: - Its App Review details

    private func reviewDetailID(
        versionID: String,
        transport: any PushTransport,
        note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> String? {
        if let known = reviewDetails[versionID] { return known }
        let id: String?
        do {
            let response = try await transport.fetch("/v1/appStoreVersions/\(versionID)/appStoreReviewDetail")
            note(response.rateLimit)
            let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            id = (object?["data"] as? [String: Any])?["id"] as? String
        } catch AppStoreConnectError.notFound {
            id = nil
        }
        reviewDetails[versionID] = id
        return id
    }

    /// The version has no App Review details: a `POST` that makes them with
    /// `request`'s fields.
    static func reviewDetailCreate(from request: PushRequest, versionID: String) -> PushRequest {
        let object = request.body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let attributes = (object?["data"] as? [String: Any])?["attributes"] as? [String: Any] ?? [:]
        let body: [String: Any] = [
            "data": [
                "type": "appStoreReviewDetails",
                "attributes": attributes,
                "relationships": ["appStoreVersion": ["data": ["type": "appStoreVersions", "id": versionID]]],
            ],
        ]
        let data = (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return PushRequest(method: .post, path: "/v1/appStoreReviewDetails", body: data)
    }
}
