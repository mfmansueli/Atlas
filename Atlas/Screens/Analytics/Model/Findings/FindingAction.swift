//
//  FindingAction.swift
//  Atlas
//

import Foundation

/// Where a finding's button goes: the section where the fix is made.
enum FindingAction: Hashable, Sendable, Codable {
    case storePage(locale: String?)
    case screenshots(locale: String?)
    case pricing(territory: String?)
    case retention
    case inAppTexts
    /// A custom product page, by name; nil opens the list.
    case productPage(name: String?)
    /// Analytics → Stability.
    case stability
    /// Analytics → Subscriptions → Billing and Plans, where Billing Grace
    /// Period is turned on.
    case billing

    /// Whether it stays inside Analytics.
    var isInsideAnalytics: Bool {
        switch self {
        case .stability, .billing: true
        default: false
        }
    }

    var area: AnalyticsArea {
        switch self {
        case .storePage: .storePage
        case .screenshots: .screenshots
        case .pricing: .pricing
        case .retention: .retention
        case .inAppTexts: .inAppTexts
        case .productPage: .productPages
        case .stability: .stability
        case .billing: .billing
        }
    }

    var title: String {
        switch self {
        case let .storePage(locale):
            if let name = locale.flatMap(StoreLocaleCatalog.locale(code:))?.name { return String(localized: "Open Store Page in \(name)") }
            return String(localized: "Open Store Page")
        case let .screenshots(locale):
            if let name = locale.flatMap(StoreLocaleCatalog.locale(code:))?.name { return String(localized: "Open Screenshots in \(name)") }
            return String(localized: "Open Screenshots")
        case let .pricing(territory):
            if let name = territory.flatMap(TerritoryCatalog.standard.territory(alpha2:))?.name { return String(localized: "Open Pricing for \(name)") }
            return String(localized: "Open Pricing")
        case .retention: return String(localized: "Open Retention")
        case .inAppTexts: return String(localized: "Open In-App Texts")
        case let .productPage(name):
            if let name { return String(localized: "Open \(name)") }
            return String(localized: "Open Product Pages")
        case .stability: return String(localized: "Open Stability")
        case .billing: return String(localized: "Turn On Billing Grace Period…")
        }
    }
}
