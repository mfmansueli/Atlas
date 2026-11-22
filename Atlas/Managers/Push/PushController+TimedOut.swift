//
//  PushController+TimedOut.swift
//  Atlas
//

import Foundation

extension PushController {
    /// A write that timed out may have been made after Atlas stopped
    /// waiting (on Alba, a new custom product page took over a minute), so
    /// it says so instead of "Not sent".
    static let timedOutText = String(localized: """
    Apple didn’t answer in time, so it may have gone through. Refresh to see before you retry.
    """)

    /// After Apple's own error for a server failure (5xx): Apple's servers
    /// sometimes give up on a slow write they still finish (a 14-language
    /// custom product page answered `UNEXPECTED_ERROR` after 30 s).
    static let serverFailureText = String(localized: "It may still have gone through: refresh to see before you retry.")

    /// Failed with `timedOutText` for a timeout, or Apple's error and
    /// `serverFailureText` for a server failure (5xx); nil for any other
    /// error, a 400 among them: that one was refused.
    static func timedOutStatus(_ error: any Error) -> PushItemStatus? {
        if let error = error as? URLError, error.code == .timedOut { return .failed(timedOutText) }
        if let error = error as? AppStoreConnectError, error.isServerFailure {
            return .failed(error.pushFailureText + " " + serverFailureText)
        }
        return nil
    }

    /// A write that failed this way may have been made anyway: Apple
    /// didn't answer in time, or its server failed (5xx).
    nonisolated static func mayHaveGoneThrough(_ error: any Error) -> Bool {
        if let error = error as? URLError { return error.code == .timedOut }
        return (error as? AppStoreConnectError)?.isServerFailure ?? false
    }
}
