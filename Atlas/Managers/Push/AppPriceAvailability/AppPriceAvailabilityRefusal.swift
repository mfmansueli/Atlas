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
            Apple refused the price. Paid prices need the Paid Applications agreement in App Store Connect → Business; \
            free needs Free Apps. Use an Admin or App Manager key.
            """)
        case .availability:
            String(localized: """
            Apple refused the availability. If you changed it in App Store Connect, discard this and refresh Pricing; \
            otherwise change one country or region at a time. Pre-orders need an unreleased app and a release date \
            Apple accepts.
            """)
        }
        return appleText.isEmpty ? cause : "\(cause) \(appleText)"
    }
}
