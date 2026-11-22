//
//  AppPriceAvailabilityRefusal.swift
//  Atlas
//

import Foundation

/// Apple refused the app's price or first availability (a 4xx): what
/// usually causes it, then Apple's code and words. Rate limits, a revoked
/// key, server failures and timeouts stay `AppStoreConnectError`, so the
/// push handles them as it does for every change.
struct AppPriceAvailabilityRefusal: LocalizedError, Hashable, Sendable {
    let kind: AppPriceAvailabilityWrite.Kind
    /// "FORBIDDEN_ERROR — …", as the push progress list shows Apple's error.
    let appleText: String

    init?(kind: AppPriceAvailabilityWrite.Kind, error: AppStoreConnectError) {
        switch error {
        case .forbidden, .rejected, .notFound:
            break
        case let .server(statusCode, _, _) where statusCode < 500:
            break
        default:
            return nil
        }
        self.kind = kind
        appleText = error.pushFailureText
    }

    var errorDescription: String? {
        let cause = switch kind {
        case .price:
            String(localized: """
            Apple refused the app’s price. A paid price needs the Paid Applications agreement to be active in App Store \
            Connect → Business (Free needs only the Free Apps agreement), and the key needs the Admin or App Manager role.
            """)
        case .availability:
            String(localized: """
            Apple refused the app’s availability. If it was set up in App Store Connect meanwhile, discard this change, \
            refresh Pricing and change countries and regions one at a time. A pre-order is only for an app that isn’t \
            released yet, with a release date Apple accepts.
            """)
        }
        return appleText.isEmpty ? cause : "\(cause) \(appleText)"
    }
}
