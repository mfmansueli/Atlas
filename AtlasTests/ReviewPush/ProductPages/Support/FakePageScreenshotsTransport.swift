//
//  FakePageScreenshotsTransport.swift
//  AtlasTests
//

import Foundation
import Synchronization
@testable import Atlas

/// Answers a custom product page's screenshot endpoints like App Store
/// Connect would and logs every call in order (`sets loc-en APP_IPHONE_67`,
/// `create set loc-en APP_IPHONE_67`, `reserve 1.png set-new`, `upload
/// shot-1 0`, `commit shot-1`, `status shot-1`, `delete old-1`, `reorder
/// set-new shot-1 shot-2`). Nothing reaches the network.
final class FakePageScreenshotsTransport: PushTransport, ScreenshotUploadTransport {
    struct Script: Sendable {
        /// The localization's set of the device and its screenshots.
        var existing: (setID: String, screenshotIDs: [String])?
        /// Status checks answered before `COMPLETE`.
        var processingChecks = 0
        /// Apple's processing reports `FAILED`.
        var fails = false
    }

    private struct State {
        var log: [String] = []
        var checks = 0
        var nextID = 1
        var uploaded: [String: Data] = [:]
        var commits: [String: String] = [:]
    }

    private let script: Script
    private let state = Mutex(State())

    init(_ script: Script = Script()) {
        self.script = script
    }

    var log: [String] { state.withLock { $0.log } }

    func uploaded(_ id: String) -> Data? { state.withLock { $0.uploaded[id] } }

    /// The MD5 the commit of `id` sent.
    func checksum(_ id: String) -> String? { state.withLock { $0.commits[id] } }

    func send(_ request: PushRequest) async throws -> AppStoreConnectResponse {
        let body = request.body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let data = body?["data"] as? [String: Any]
        let attributes = data?["attributes"] as? [String: Any]
        let relationships = data?["relationships"] as? [String: Any]
        let parts = request.path.split(separator: "/").map(String.init)
        switch (request.method, parts.count > 1 ? parts[1] : "") {
        case (.post, "appScreenshotSets"), (.post, "appPreviewSets"):
            let localization = (relationships?["appCustomProductPageLocalization"] as? [String: Any])?["data"] as? [String: Any]
            let kind = attributes?["screenshotDisplayType"] as? String ?? attributes?["previewType"] as? String ?? ""
            append("create \(parts[1]) \(localization?["id"] as? String ?? "") \(kind)".replacingOccurrences(of: "create appScreenshotSets", with: "create set"))
            return try response(["data": ["type": parts[1], "id": "set-new"]])
        case (.post, "appScreenshots"), (.post, "appPreviews"):
            let set = (relationships?["appScreenshotSet"] as? [String: Any] ?? relationships?["appPreviewSet"] as? [String: Any])?["data"] as? [String: Any]
            let mime = (attributes?["mimeType"] as? String).map { " " + $0 } ?? ""
            let id = state.withLock { state -> String in
                defer { state.nextID += 1 }
                state.log.append("reserve \(attributes?["fileName"] as? String ?? "") \(set?["id"] as? String ?? "")\(mime)")
                return "shot-\(state.nextID)"
            }
            let size = attributes?["fileSize"] as? Int ?? 0
            let operation: [String: Any] = ["method": "PUT", "url": "https://upload.example/\(id)/0", "offset": 0, "length": size, "requestHeaders": []]
            return try response(["data": ["type": "appScreenshots", "id": id, "attributes": ["uploadOperations": [operation]]]])
        case (.patch, "appScreenshots"), (.patch, "appPreviews"):
            let id = parts.last ?? ""
            state.withLock { state in
                state.log.append("commit \(id)")
                state.commits[id] = attributes?["sourceFileChecksum"] as? String
            }
            return try response(["data": ["type": "appScreenshots", "id": id]])
        case (.patch, "appScreenshotSets"), (.patch, "appPreviewSets"):
            let ids = (body?["data"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
            append((["reorder", parts[2]] + ids).joined(separator: " "))
            return AppStoreConnectResponse(data: Data(), rateLimit: nil)
        case (.delete, _):
            append("delete \(parts.last ?? "")")
            return AppStoreConnectResponse(data: Data(), rateLimit: nil)
        default:
            append("unexpected \(request.method) \(request.path)")
            throw AppStoreConnectError.unexpectedPayload
        }
    }

    func fetch(_ path: String) async throws -> AppStoreConnectResponse {
        let parts = path.split(separator: "?")[0].split(separator: "/").map(String.init)
        if parts.count == 4, parts[1] == "appCustomProductPageLocalizations" {
            let query = URLComponents(string: "https://x\(path)")?.queryItems ?? []
            let isPreviews = parts[3] == "appPreviewSets"
            let kindField = isPreviews ? "previewType" : "screenshotDisplayType"
            let items = isPreviews ? "appPreviews" : "appScreenshots"
            let display = query.first { $0.name == "filter[\(kindField)]" }?.value ?? ""
            append("\(isPreviews ? "preview sets" : "sets") \(parts[2]) \(display)")
            guard let existing = script.existing else { return try response(["data": []]) }
            let screenshots = existing.screenshotIDs.map { ["type": items, "id": $0] }
            return try response(["data": [[
                "type": parts[3], "id": existing.setID,
                "attributes": [kindField: display],
                "relationships": [items: ["data": screenshots]],
            ]]])
        }
        let id = parts.last ?? ""
        let checks = state.withLock { state -> Int in
            state.checks += 1
            state.log.append("status \(id)")
            return state.checks
        }
        var delivery: [String: Any] = ["state": script.fails ? "FAILED" : checks > script.processingChecks ? "COMPLETE" : "UPLOAD_COMPLETE"]
        if script.fails { delivery["errors"] = [["code": "IMAGE_TOOL_FAILURE", "description": "The image couldn’t be read."]] }
        return try response(["data": ["type": "appScreenshots", "id": id, "attributes": ["assetDeliveryState": delivery]]])
    }

    func upload(_ operation: ScreenshotUploadOperation, data: Data, progress _: @escaping @Sendable (Int64) -> Void) async throws {
        let parts = operation.url.split(separator: "/")
        let id = String(parts[parts.count - 2])
        state.withLock { state in
            state.log.append("upload \(id) \(parts.last ?? "")")
            state.uploaded[id, default: Data()].append(operation.slice(of: data))
        }
    }

    private func append(_ line: String) {
        state.withLock { $0.log.append(line) }
    }

    private func response(_ object: [String: Any]) throws -> AppStoreConnectResponse {
        try AppStoreConnectResponse(data: JSONSerialization.data(withJSONObject: object), rateLimit: nil)
    }
}
