//
//  AppStoreConnectReadRetry.swift
//  Atlas
//

import Foundation

/// How a read (`GET`) is asked again after Apple's server failed on it
/// (a 5xx, `AppStoreConnectError.isServerFailure`, the same test the
/// product page push recovery uses). A read changes nothing, so asking
/// again is safe, and Apple's 500s on reads usually pass: on Atlas's own
/// app (2026-11-22), Pricing's first read after a push that had just made
/// two subscriptions and their 175 prices waited 12 s for
/// `UNEXPECTED_ERROR`, while the same read a moment later answered in
/// 0.3 s. Refusals (4xx), the hourly limit and being offline aren't asked
/// again: they don't pass in a second.
struct AppStoreConnectReadRetry: Sendable {
    /// The wait before each new try, in order: one try more per pause.
    var pauses: [Duration]
    var sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }

    /// Two more tries, about 3 seconds in all.
    static let standard = AppStoreConnectReadRetry(pauses: [.seconds(1), .seconds(2)])
    /// Tests: the same tries, without waiting.
    static let immediate = AppStoreConnectReadRetry(pauses: [.zero, .zero])
    /// One try only.
    static let never = AppStoreConnectReadRetry(pauses: [])

    /// `read`'s answer, asking again after each pause while Apple's server
    /// fails; the last failure is thrown. Cancelling stops the waiting.
    func run<Value>(_ read: () async throws -> Value) async throws -> Value {
        for pause in pauses {
            do {
                return try await read()
            } catch let error as AppStoreConnectError where error.isServerFailure {
                try await sleep(pause)
            }
        }
        return try await read()
    }
}
