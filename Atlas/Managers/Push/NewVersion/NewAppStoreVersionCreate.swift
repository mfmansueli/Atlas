//
//  NewAppStoreVersionCreate.swift
//  Atlas
//

import Foundation

/// A new version's `POST /v1/appStoreVersions`. A push that stopped after
/// it sends it again; App Store Connect refuses a number it already has, so
/// the push looks the version up by number and platform and counts it as
/// created instead of failing forever.
struct NewAppStoreVersionCreate: Hashable, Sendable {
    var request: PushRequest
    var appID: String
    var version: NewAppVersion

    init?(_ request: PushRequest) {
        guard request.method == .post, request.path == NewAppVersionChangeBuilder.path, let body = request.body,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let data = object["data"] as? [String: Any],
              let attributes = data["attributes"] as? [String: Any],
              let versionString = attributes["versionString"] as? String,
              let platform = attributes["platform"] as? String,
              let app = ((data["relationships"] as? [String: Any])?["app"] as? [String: Any])?["data"] as? [String: Any],
              let appID = app["id"] as? String
        else { return nil }
        self.request = request
        self.appID = appID
        version = NewAppVersion(versionString: versionString, platform: platform)
    }

    /// `GET` the app's versions with that number on that platform.
    var lookupPath: String {
        let number = version.versionString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? version.versionString
        return "/v1/apps/\(appID)/appStoreVersions?filter%5BversionString%5D=\(number)"
            + "&filter%5Bplatform%5D=\(version.platform)&fields%5BappStoreVersions%5D=versionString,platform&limit=200"
    }

    /// The version with exactly that number and platform.
    func versionID(in data: Data) -> String? {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let versions = object?["data"] as? [[String: Any]] ?? []
        return versions.first { resource in
            let attributes = resource["attributes"] as? [String: Any]
            return attributes?["versionString"] as? String == version.versionString
                && (attributes?["platform"] as? String).map { $0 == version.platform } ?? true
        }?["id"] as? String
    }

    /// A refusal that may mean the number is taken: 409, 422 or 400.
    static func mayBeTaken(_ refusal: AppStoreConnectError) -> Bool {
        NewSubscriptionCreate.mayBeTaken(refusal)
    }

    /// Creates the version, or finds the one a push made before. Returns
    /// its ID; `note` gets each response's rate limit. Throws App Store
    /// Connect's refusal when the app doesn't have it.
    @MainActor
    func send(via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void) async throws -> String {
        do {
            let response = try await transport.send(request)
            note(response.rateLimit)
            let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            guard let id = (object?["data"] as? [String: Any])?["id"] as? String else { throw AppStoreConnectError.unexpectedPayload }
            return id
        } catch let refusal as AppStoreConnectError {
            guard Self.mayBeTaken(refusal) else { throw refusal }
            let found = try await transport.fetch(lookupPath)
            note(found.rateLimit)
            guard let id = versionID(in: found.data) else { throw refusal }
            return id
        }
    }
}
