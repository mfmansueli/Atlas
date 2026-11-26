//
//  FindingAction.swift
//  Atlas
//

import Foundation

/// Where a finding's button goes: the section where the fix is made.
enum FindingAction: Hashable, Sendable, Codable {
    case storePage(locale: String?)
    case screenshots(locale: String?)
    /// One device's screenshots, on `locale`'s page (the primary
    /// language's, from a device row in Break It Down).
    case screenshotsOnDevice(ScreenshotDisplayType, locale: String)
    case pricing(territory: String?)
    /// Pricing → Results: a price change's result, per territory, from
    /// After Changes.
    case pricingResults
    case retention
    /// Pricing → Retention with a new message started, for an offer:
    /// "Try an Offer Message…".
    case offerMessage
    /// Pricing → Retention, to write messages for the languages that show
    /// Apple's plain screen: "Write Messages for N Languages…".
    case retentionLanguages(count: Int)
    case inAppTexts
    /// A custom product page, by name; nil opens the list.
    case productPage(name: String?)
    /// A custom product page's screenshots, by name: "Make Screenshots for
    /// This Page…".
    case pageScreenshots(name: String)
    /// Analytics → After Changes, where each push's result shows.
    case changes
    /// Analytics → Stability.
    case stability
    /// Analytics → Subscriptions → Billing and Plans, where Billing Grace
    /// Period is turned on.
    case billing

    /// Whether it stays inside Analytics.
    var isInsideAnalytics: Bool {
        switch self {
        case .stability, .billing, .changes: true
        default: false
        }
    }

    var area: AnalyticsArea {
        switch self {
        case .storePage: .storePage
        case .screenshots, .screenshotsOnDevice: .screenshots
        case .pricing, .pricingResults: .pricing
        case .retention, .offerMessage, .retentionLanguages: .retention
        case .inAppTexts: .inAppTexts
        case .productPage, .pageScreenshots: .productPages
        // What changed with a version: its crashes, or what was pushed.
        case .stability, .changes: .stability
        case .billing: .billing
        }
    }

    /// The Analytics view it opens, for one that stays inside Analytics.
    var analyticsTab: AnalyticsTab? {
        switch self {
        case .stability: .stability
        case .billing: .subscriptions
        case .changes: .afterChanges
        default: nil
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
        case let .screenshotsOnDevice(displayType, _):
            return String(localized: "Open \(displayType.title) Screenshots", comment: "kind:button")
        case let .pricing(territory):
            if let name = territory.flatMap(TerritoryCatalog.standard.territory(alpha2:))?.name { return String(localized: "Open Pricing for \(name)") }
            return String(localized: "Open Pricing")
        case .pricingResults: return String(localized: "Open Pricing Results", comment: "kind:button")
        case .retention: return String(localized: "Open Retention")
        case .offerMessage: return String(localized: "Try an Offer Message…", comment: "kind:button")
        case let .retentionLanguages(count):
            return count == 1
                ? String(localized: "Write a Message for 1 Language…", comment: "kind:button")
                : String(localized: "Write Messages for \(count) Languages…", comment: "kind:button")
        case .inAppTexts: return String(localized: "Open In-App Texts")
        case let .productPage(name):
            if let name { return String(localized: "Open \(name)") }
            return String(localized: "Open Custom Product Pages")
        case .pageScreenshots: return String(localized: "Make Screenshots for This Page…", comment: "kind:section-title")
        case .changes: return String(localized: "See After Changes", comment: "kind:button")
        case .stability: return String(localized: "Open Stability")
        case .billing: return String(localized: "Turn On Billing Grace Period…")
        }
    }
}
