//
//  FakeNewLanguageTransport.swift
//  AtlasTests
//

import Foundation
import Synchronization
@testable import Atlas

/// An event's languages as App Store Connect keeps them: a texts `POST`
/// creates one (`loc-<locale>`) and `GET /v1/appEvents/<id>/localizations`
/// lists them. Everything about images goes to `artwork`. `log` reads
/// `create fr-FR`, `languages winter`.
final class FakeNewLanguageTransport: PushTransport, ScreenshotUploadTransport {
    let artwork = FakeEventArtworkTransport()
    private let state: Mutex<(log: [String], languages: [String: String])>

    init(languages: [String: String]) {
        state = Mutex(([], languages))
    }

    var log: [String] { state.withLock { $0.log } }

    func send(_ request: PushRequest) async throws -> AppStoreConnectResponse {
        guard request.method == .post, request.path == "/v1/\(InAppEventWriteDocument.type)",
              let locale = InAppEventWriteDocument.decode(request.body)?.data.attributes["locale"]
        else { return try await artwork.send(request) }
        let id = "loc-\(locale)"
        state.withLock { state in
            state.log.append("create \(locale)")
            state.languages[locale] = id
        }
        return try Self.response(["data": ["type": InAppEventWriteDocument.type, "id": id]])
    }

    func fetch(_ path: String) async throws -> AppStoreConnectResponse {
        let parts = path.split(separator: "?")[0].split(separator: "/").map(String.init)
        guard parts.count == 4, parts[1] == "appEvents", parts[3] == "localizations" else { return try await artwork.fetch(path) }
        let languages = state.withLock { state in
            state.log.append("languages \(parts[2])")
            return state.languages
        }
        let items = languages.sorted { $0.key < $1.key }.map { locale, id -> [String: Any] in
            ["type": "appEventLocalizations", "id": id, "attributes": ["locale": locale]]
        }
        return try Self.response(["data": items])
    }

    func upload(_ operation: ScreenshotUploadOperation, data: Data, progress: @escaping @Sendable (Int64) -> Void) async throws {
        try await artwork.upload(operation, data: data, progress: progress)
    }

    private static func response(_ object: [String: Any]) throws -> AppStoreConnectResponse {
        try AppStoreConnectResponse(data: JSONSerialization.data(withJSONObject: object), rateLimit: nil)
    }
}
