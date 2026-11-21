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

    /// Failed with `timedOutText` for a timeout; nil for any other error.
    static func timedOutStatus(_ error: any Error) -> PushItemStatus? {
        guard let error = error as? URLError, error.code == .timedOut else { return nil }
        return .failed(timedOutText)
    }
}
