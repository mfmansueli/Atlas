//
//  AnalyticsActionError.swift
//  Atlas
//

import Foundation

/// Why one of Analytics' few writes couldn't be made.
enum AnalyticsActionError: LocalizedError, Equatable {
    /// App Store Connect has no Billing Grace Period for the app: it sells
    /// no subscription, or the key can't read it.
    case noGracePeriodSetting

    var errorDescription: String? {
        switch self {
        case .noGracePeriodSetting:
            String(localized: "App Store Connect has no Billing Grace Period setting for this app. Turn it on in App Store Connect → Subscriptions.")
        }
    }
}
