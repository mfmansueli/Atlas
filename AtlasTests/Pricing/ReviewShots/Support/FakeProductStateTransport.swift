//
//  FakeProductStateTransport.swift
//  AtlasTests
//

import Foundation
import Synchronization
@testable import Atlas

/// Answers a product's state, and a one-item page for every other read:
/// empty for paths containing one of `empty`, 404 for `missing`, an error
/// for `failing`.
final class FakeProductStateTransport: PushTransport {
    let state: String
    let empty: [String]
    let missing: [String]
    let failing: [String]
    private let log = Mutex<[String]>([])

    init(state: String, empty: [String] = [], missing: [String] = [], failing: [String] = []) {
        self.state = state
        self.empty = empty
        self.missing = missing
        self.failing = failing
    }

    var paths: [String] { log.withLock { $0 } }

    func send(_: PushRequest) async throws -> AppStoreConnectResponse {
        AppStoreConnectResponse(data: Data(), rateLimit: nil)
    }

    func fetch(_ path: String) async throws -> AppStoreConnectResponse {
        log.withLock { $0.append(path) }
        if path.contains("fields%5B") {
            return AppStoreConnectResponse(data: Data(#"{"data":{"id":"x","attributes":{"state":"\#(state)"}}}"#.utf8), rateLimit: nil)
        }
        if failing.contains(where: path.contains) { throw URLError(.timedOut) }
        if missing.contains(where: path.contains) { throw AppStoreConnectError.notFound(detail: nil) }
        let body = empty.contains(where: path.contains) ? #"{"data":[]}"# : #"{"data":[{"id":"1"}]}"#
        return AppStoreConnectResponse(data: Data(body.utf8), rateLimit: nil)
    }
}
