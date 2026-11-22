//
//  PushSlots.swift
//  Atlas
//

import Foundation
import Synchronization

/// How many of one kind of work of a push go at once, beside the changes
/// `PushSchedule` runs side by side:
/// - Width 1 (`run(_:)`): one at a time per key, in the order they came,
///   for a step changes share that must happen once (a new subscription
///   group found or made, an In-App Texts draft, App Store Connect's
///   territories read).
/// - A wider key (`forEach`): many similar requests of one change (a
///   subscription's price in every territory) go up to
///   `PushSchedule.concurrentRequests` at once, and every change fanning
///   out under the same key shares those places.
///
/// One per push (`PushController`). Operations run in the caller's
/// isolation (the push's main actor); the places are kept under a lock.
final class PushSlots: Sendable {
    private struct State {
        /// Operations going now, by key.
        var running: [String: Int] = [:]
        /// Operations waiting for a place, by key, first come first served.
        var waiting: [String: [CheckedContinuation<Void, Never>]] = [:]
    }

    private let state = Mutex(State())

    /// Runs `operation` once fewer than `width` others of `key` are going.
    func run<T>(
        _ key: String,
        width: Int = 1,
        isolation _: isolated (any Actor)? = #isolation,
        _ operation: () async throws -> T
    ) async rethrows -> T {
        await take(key, width: width)
        defer { leave(key) }
        return try await operation()
    }

    /// Runs `operation` for every item, up to `width` at once (and at most
    /// `width` of `key` in the whole push), calling `finished` in the
    /// caller's isolation as each one comes back, in the order they finish.
    /// After a failure no other item starts: those going finish, then the
    /// first error is thrown.
    func forEach<Item: Sendable, Output: Sendable>(
        _ items: [Item],
        key: String,
        width: Int = PushSchedule.concurrentRequests,
        isolation: isolated (any Actor)? = #isolation,
        _ operation: @escaping @Sendable (Item) async throws -> Output,
        finished: (Item, Output) -> Void
    ) async throws {
        var failure: (any Error)?
        var pending = items[...]
        var going = 0
        // The group's body must run in the caller's isolation: a closure is
        // isolated to an `isolated` parameter only when it captures it. Left
        // uncaptured, the body (and `finished`) ran on the generic executor
        // and a push's main-actor rate tracker trapped on its isolation check.
        await withTaskGroup(of: Result<(Item, Output), any Error>.self, isolation: isolation) { group in
            _ = isolation
            while true {
                while failure == nil, going < max(1, width), let item = pending.popFirst() {
                    going += 1
                    group.addTask { [self] in
                        await take(key, width: width)
                        defer { leave(key) }
                        do {
                            return try await .success((item, operation(item)))
                        } catch {
                            return .failure(error)
                        }
                    }
                }
                guard going > 0, let result = await group.next() else { break }
                going -= 1
                switch result {
                case let .success((item, output)): finished(item, output)
                case let .failure(error): failure = failure ?? error
                }
            }
        }
        if let failure { throw failure }
    }

    /// Operations of `key` going now (tests).
    func runningCount(_ key: String) -> Int {
        state.withLock { $0.running[key] ?? 0 }
    }

    // MARK: - Places

    private func take(_ key: String, width: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let now = state.withLock { state in
                guard state.running[key, default: 0] < max(1, width) else {
                    state.waiting[key, default: []].append(continuation)
                    return false
                }
                state.running[key, default: 0] += 1
                return true
            }
            if now { continuation.resume() }
        }
    }

    /// Hands the place to the first waiting, or frees it.
    private func leave(_ key: String) {
        let next = state.withLock { state -> CheckedContinuation<Void, Never>? in
            if var queue = state.waiting[key], !queue.isEmpty {
                let next = queue.removeFirst()
                state.waiting[key] = queue.isEmpty ? nil : queue
                return next
            }
            state.running[key, default: 1] -= 1
            if state.running[key] == 0 { state.running[key] = nil }
            return nil
        }
        next?.resume()
    }
}
