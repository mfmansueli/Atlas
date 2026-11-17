//
//  FakeEventArtworkTransport.swift
//  AtlasTests
//

import Foundation
import Synchronization
@testable import Atlas

/// Answers the In-App Event media endpoints like App Store Connect would
/// and logs every call in order (`list appEventScreenshots loc-en`,
/// `reserve appEventScreenshots card.png EVENT_CARD loc-en`, `upload
/// shot-1 0`, `commit appEventScreenshots shot-1`, `status shot-1`,
/// `delete appEventScreenshots old-card`). Nothing reaches the network.
final class FakeEventArtworkTransport: PushTransport, ScreenshotUploadTransport {
    struct Script: Sendable {
        /// What the localization has: (id, asset type), by resource type.
        var existing: [String: [(id: String, type: String)]] = [:]
        /// Reserving while one of the type exists is refused with 409, once.
        var refusesSecondOfType = false
        /// Status checks answered before `COMPLETE`.
        var processingChecks = 0
        /// Apple's processing reports `FAILED`.
        var fails = false
        /// Parts per reservation.
        var parts = 2
    }

    private struct State {
        var log: [String] = []
        var bodies: [String: Data] = [:]
        var checks = 0
        var refused = false
        var nextID = 1
        var uploaded: [String: Data] = [:]
    }

    private let script: Script
    private let state: Mutex<State>

    init(_ script: Script = Script()) {
        self.script = script
        state = Mutex(State())
    }

    var log: [String] { state.withLock { $0.log } }

    /// The JSON body last sent with the `log` line's first two words.
    func body(_ key: String) -> [String: Any]? {
        let data = state.withLock { $0.bodies[key] }
        return data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }

    func uploaded(_ id: String) -> Data? {
        state.withLock { $0.uploaded[id] }
    }

    func send(_ request: PushRequest) async throws -> AppStoreConnectResponse {
        let body = request.body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let data = body?["data"] as? [String: Any]
        let attributes = data?["attributes"] as? [String: Any]
        let parts = request.path.split(separator: "/").map(String.init)
        let type = parts.count > 1 ? parts[1] : ""
        switch request.method {
        case .post:
            let localization = ((data?["relationships"] as? [String: Any])?["appEventLocalization"] as? [String: Any])?["data"] as? [String: Any]
            let assetType = attributes?["appEventAssetType"] as? String ?? ""
            let line = "reserve \(type) \(attributes?["fileName"] as? String ?? "") \(assetType) \(localization?["id"] as? String ?? "")"
            let refuse = state.withLock { state -> Bool in
                let hasOne = script.existing.values.joined().contains { $0.type == assetType } && !state.log.contains { $0.hasPrefix("delete") }
                guard script.refusesSecondOfType, hasOne, !state.refused else { return false }
                state.refused = true
                state.log.append("\(line) refused")
                return true
            }
            if refuse { throw AppStoreConnectError.rejected(statusCode: 409, code: "STATE_ERROR", detail: "Only one of each asset type.") }
            let id = record(line, body: request.body, prefix: type == "appEventVideoClips" ? "clip" : "shot")
            let operations: [[String: Any]] = (0..<script.parts).map { part in
                ["method": "PUT", "url": "https://upload.example/\(id)/\(part)", "offset": part * 100, "length": 100, "requestHeaders": []]
            }
            return try response(["data": ["type": type, "id": id, "attributes": ["uploadOperations": operations]]])
        case .patch:
            record("commit \(type) \(parts.last ?? "")", body: request.body)
            return try response(["data": ["type": type, "id": parts.last ?? ""]])
        case .delete:
            record("delete \(type) \(parts.last ?? "")", body: nil)
            return AppStoreConnectResponse(data: Data(), rateLimit: nil)
        default:
            return AppStoreConnectResponse(data: Data("{}".utf8), rateLimit: nil)
        }
    }

    func fetch(_ path: String) async throws -> AppStoreConnectResponse {
        let parts = path.split(separator: "?")[0].split(separator: "/").map(String.init)
        if parts.count == 4, parts[1] == "appEventLocalizations" {
            record("list \(parts[3]) \(parts[2])", body: nil)
            let items = (script.existing[parts[3]] ?? []).map { item -> [String: Any] in
                ["type": parts[3], "id": item.id, "attributes": ["appEventAssetType": item.type]]
            }
            return try response(["data": items])
        }
        let id = parts.last ?? ""
        let checks = state.withLock { state -> Int in
            state.checks += 1
            state.log.append("status \(id)")
            return state.checks
        }
        let value = script.fails ? "FAILED" : checks > script.processingChecks ? "COMPLETE" : "UPLOAD_COMPLETE"
        var delivery: [String: Any] = ["state": value]
        if script.fails { delivery["errors"] = [["code": "IMAGE_TOOL_FAILURE", "description": "The image couldn’t be read."]] }
        let field = parts[1] == "appEventVideoClips" ? "videoDeliveryState" : "assetDeliveryState"
        return try response(["data": ["type": parts[1], "id": id, "attributes": [field: delivery]]])
    }

    func upload(_ operation: ScreenshotUploadOperation, data: Data, progress _: @escaping @Sendable (Int64) -> Void) async throws {
        let parts = operation.url.split(separator: "/")
        let id = String(parts[parts.count - 2])
        state.withLock { state in
            state.log.append("upload \(id) \(parts.last ?? "")")
            state.uploaded[id, default: Data()].append(operation.slice(of: data))
        }
    }

    @discardableResult
    private func record(_ line: String, body: Data?, prefix: String? = nil) -> String {
        state.withLock { state in
            state.log.append(line)
            let key = line.split(separator: " ").prefix(2).joined(separator: " ")
            if let body { state.bodies[key] = body }
            guard let prefix else { return "" }
            defer { state.nextID += 1 }
            return "\(prefix)-\(state.nextID)"
        }
    }

    private func response(_ object: [String: Any]) throws -> AppStoreConnectResponse {
        try AppStoreConnectResponse(data: JSONSerialization.data(withJSONObject: object), rateLimit: nil)
    }
}
