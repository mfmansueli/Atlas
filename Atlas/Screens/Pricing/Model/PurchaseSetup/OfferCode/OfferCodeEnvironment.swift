//
//  OfferCodeEnvironment.swift
//  Atlas
//

import Foundation

/// Where one-time codes redeem: on the App Store, or in the sandbox for
/// testing. App Store Connect's `OfferCodeEnvironment`.
enum OfferCodeEnvironment: String, CaseIterable, Hashable, Sendable {
    case production = "PRODUCTION"
    case sandbox = "SANDBOX"

    var title: String {
        switch self {
        case .production: String(localized: "App Store")
        case .sandbox: String(localized: "Sandbox, for testing")
        }
    }
}
