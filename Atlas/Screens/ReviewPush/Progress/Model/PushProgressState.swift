//
//  PushProgressState.swift
//  Atlas
//

import Foundation

/// Where one row of a push stands, whatever sends it: waiting its turn, on
/// its way (uploading, with Apple, being placed), done, failed with the
/// reason, or not sent (cancelled, stopped, or changed in App Store Connect
/// meanwhile).
enum PushProgressState: Hashable, Sendable {
    case waiting
    case sending
    case done
    case failed(String)
    case notSent

    var isFinished: Bool {
        switch self {
        case .waiting, .sending: false
        case .done, .failed, .notSent: true
        }
    }

    /// Why it failed; nil unless it did.
    var failureReason: String? {
        if case let .failed(reason) = self { return reason }
        return nil
    }
}
