//
//  SlowPushTransport.swift
//  AtlasTests
//

import Foundation
import Synchronization
@testable import Atlas

/// A transport whose writes take a moment, recording the order they
/// started in and the most that were in flight at once.
final class SlowPushTransport: PushTransport {
    private struct State {
        var started: [String] = []
        var inFlight = 0
        var mostInFlight = 0
        /// Paths in flight together with each one, when it started.
        var overlaps: [String: Set<String>] = [:]
        var running: Set<String> = []
    }

    private let state = Mutex(State())
    private let delay: Duration

    init(delay: Duration = .milliseconds(40)) {
        self.delay = delay
    }

    var started: [String] { state.withLock { $0.started } }
    var mostInFlight: Int { state.withLock { $0.mostInFlight } }

    /// Whether `path` was ever in flight together with `other`.
    func overlapped(_ path: String, _ other: String) -> Bool {
        state.withLock { ($0.overlaps[path] ?? []).contains(other) || ($0.overlaps[other] ?? []).contains(path) }
    }

    func send(_ request: PushRequest) async throws -> AppStoreConnectResponse {
        state.withLock { state in
            state.started.append(request.path)
            for other in state.running {
                state.overlaps[request.path, default: []].insert(other)
            }
            state.running.insert(request.path)
            state.inFlight += 1
            state.mostInFlight = max(state.mostInFlight, state.inFlight)
        }
        try? await Task.sleep(for: delay)
        state.withLock { state in
            state.inFlight -= 1
            state.running.remove(request.path)
        }
        return AppStoreConnectResponse(data: Data(), rateLimit: nil)
    }

    func fetch(_: String) async throws -> AppStoreConnectResponse {
        AppStoreConnectResponse(data: Data("{}".utf8), rateLimit: nil)
    }
}
