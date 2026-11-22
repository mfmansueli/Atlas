//
//  PricingReadFailure.swift
//  Atlas
//

import Foundation

/// A product's prices that Apple's server failed to send, even after the
/// read was asked again (`AppStoreConnectReadRetry`). It belongs to that
/// product alone: its card (or its prices) says so with Try Again, the
/// other products still show, and no workspace banner repeats Apple's
/// "An unexpected error occurred on the server side…".
enum PricingReadFailure {
    /// Apple's server failed (5xx): the product says so itself.
    static func isProductFailure(_ error: any Error) -> Bool {
        (error as? AppStoreConnectError)?.isServerFailure ?? false
    }

    /// "Couldn’t read Atlas Pro Yearly’s prices. App Store Connect had a
    /// problem on its side."
    static func text(productName: String) -> String {
        String(localized: "Couldn’t read \(productName)’s prices. App Store Connect had a problem on its side.")
    }
}
