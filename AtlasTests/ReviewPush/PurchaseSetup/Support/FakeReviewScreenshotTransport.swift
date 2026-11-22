//
//  FakeReviewScreenshotTransport.swift
//  AtlasTests
//

import Foundation
import Synchronization
@testable import Atlas

/// Answers the App Review screenshot endpoints of subscriptions and in-app
/// purchases like App Store Connect would, logging every call in order
/// (`current sub1`, `delete old1`, `reserve paywall.png 1234 sub1`, `upload
/// rs1 0`, `commit rs1 <md5>`, `status rs1`). Nothing reaches the network.
final class FakeReviewScreenshotTransport: PushTransport, ScreenshotUploadTransport {
    struct Script: Sendable {
        /// The screenshot the product has: (id, MD5, state).
        var current: (id: String, checksum: String, state: String)?
        /// Status checks answered `UPLOAD_COMPLETE` before `COMPLETE`.
        var processingChecks = 1
        /// Apple's processing reports `FAILED`.
        var fails = false
    }

    private let script: Script
    private let state = Mutex<(log: [String], uploaded: Data, checks: Int)>(([], Data(), 0))

    init(_ script: Script = Script()) {
        self.script = script
    }

    var log: [String] { state.withLock { $0.log } }
    var uploaded: Data { state.withLock { $0.uploaded } }

    private func append(_ line: String) {
        state.withLock { $0.log.append(line) }
    }

    func send(_ request: PushRequest) async throws -> AppStoreConnectResponse {
        let body = request.body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let data = body?["data"] as? [String: Any]
        let attributes = data?["attributes"] as? [String: Any]
        let id = request.path.split(separator: "/").last.map(String.init) ?? ""
        switch request.method {
        case .post:
            let relationships = data?["relationships"] as? [String: Any] ?? [:]
            let owner = relationships.values.compactMap { (($0 as? [String: Any])?["data"] as? [String: Any])?["id"] as? String }.first ?? ""
            append("reserve \(attributes?["fileName"] as? String ?? "") \(attributes?["fileSize"] as? Int ?? 0) \(owner)")
            let half = (attributes?["fileSize"] as? Int ?? 0) / 2
            let operations = """
            [{"method":"PUT","url":"https://upload.example/rs1/0","offset":0,"length":\(half),"requestHeaders":[]},\
            {"method":"PUT","url":"https://upload.example/rs1/1","offset":\(half),"length":\((attributes?["fileSize"] as? Int ?? 0) - half),"requestHeaders":[]}]
            """
            let reply = #"{"data":{"type":"x","id":"rs1","attributes":{"uploadOperations":\#(operations)}}}"#
            return AppStoreConnectResponse(data: Data(reply.utf8), rateLimit: nil)
        case .patch:
            append("commit \(id) \(attributes?["sourceFileChecksum"] as? String ?? "") \(attributes?["uploaded"] as? Bool ?? false)")
        case .delete:
            append("delete \(id)")
        }
        return AppStoreConnectResponse(data: Data(), rateLimit: nil)
    }

    func fetch(_ path: String) async throws -> AppStoreConnectResponse {
        if path.contains("/appStoreReviewScreenshot") {
            let owner = path.split(separator: "/").dropFirst(2).first.map(String.init) ?? ""
            append("current \(owner)")
            guard let current = script.current else { throw AppStoreConnectError.notFound(detail: nil) }
            let reply = #"""
            {"data":{"id":"\#(current.id)","attributes":{"fileName":"old.png","sourceFileChecksum":"\#(current.checksum)",\#
            "assetDeliveryState":{"state":"\#(current.state)"}}}}
            """#
            return AppStoreConnectResponse(data: Data(reply.utf8), rateLimit: nil)
        }
        let id = path.split(separator: "/").last.map { String($0.split(separator: "?").first ?? $0) } ?? ""
        append("status \(id)")
        let checks = state.withLock { state -> Int in
            state.checks += 1
            return state.checks
        }
        let delivery = script.fails ? "FAILED" : (checks > script.processingChecks ? "COMPLETE" : "UPLOAD_COMPLETE")
        let errors = script.fails ? #","errors":[{"code":"IMAGE_TOOL_FAILURE","description":"The image couldn't be read."}]"# : ""
        let reply = #"{"data":{"id":"\#(id)","attributes":{"assetDeliveryState":{"state":"\#(delivery)"\#(errors)}}}}"#
        return AppStoreConnectResponse(data: Data(reply.utf8), rateLimit: nil)
    }

    func upload(_ operation: ScreenshotUploadOperation, data: Data, progress _: @escaping @Sendable (Int64) -> Void) async throws {
        let part = operation.url.split(separator: "/").suffix(2).joined(separator: " ")
        state.withLock {
            $0.log.append("upload \(part)")
            $0.uploaded.append(operation.slice(of: data))
        }
    }
}
