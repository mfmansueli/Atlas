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

    var area: AnalyticsArea {
        switch self {
        case .storePage: .storePage
        case .screenshots: .screenshots
        case .pricing: .pricing
        case .retention: .retention
        case .inAppTexts: .inAppTexts
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
        }
    }
}
