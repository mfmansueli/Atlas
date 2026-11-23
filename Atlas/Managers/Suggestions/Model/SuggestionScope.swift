//
//  SuggestionScope.swift
//  Atlas
//

import Foundation

/// Where a suggestion is shown: one Store Page language, one App
/// Information page, Accessibility on one device, or App Privacy's URLs in
/// one language. The suggestion bar works on one scope at a time.
enum SuggestionScope: Hashable, Codable, Sendable {
    /// A Store Page language, by App Store Connect locale code, e.g. `de-DE`.
    case storePage(locale: String)
    /// An App Information page, by `AppInformationPage` raw value:
    /// `general`, `ageRating`, `appReview`, or `accessibility` for its URL.
    case appInformation(page: String)
    /// Accessibility on one device, by `DeviceFamily` raw value, e.g.
    /// `APPLE_WATCH`.
    case accessibility(family: String)
    /// App Privacy's User Privacy Choices URL in one language, by App
    /// Store Connect locale code (an `appInfoLocalizations` attribute).
    case appPrivacy(locale: String)

    var area: SuggestionArea {
        switch self {
        case .storePage: .storePage
        case .appInformation, .accessibility, .appPrivacy: .appInformation
        }
    }

    /// `store.de-DE` or `info.general`, for ids and MCP results.
    var id: String {
        switch self {
        case let .storePage(locale): "store.\(locale)"
        case let .appInformation(page): "info.\(page)"
        case let .accessibility(family): "info.accessibility.\(family)"
        case let .appPrivacy(locale): "info.appPrivacy.\(locale)"
        }
    }

    /// "German" or "App Review", as the bar and toasts name it.
    var title: String {
        switch self {
        case let .storePage(code): StoreLocaleCatalog.locale(code: code)?.name ?? code
        case let .appInformation(page): AppInformationPage(rawValue: page)?.title ?? page
        case let .accessibility(family):
            "\(AppInformationPage.accessibility.title) · \(DeviceFamily(rawValue: family)?.name ?? family)"
        case let .appPrivacy(code):
            "\(AppInformationPage.appPrivacy.title) · \(StoreLocaleCatalog.locale(code: code)?.name ?? code)"
        }
    }

    static func appInformation(_ page: AppInformationPage) -> SuggestionScope {
        .appInformation(page: page.rawValue)
    }

    static func accessibility(_ family: DeviceFamily) -> SuggestionScope {
        .accessibility(family: family.rawValue)
    }

    static func appPrivacy(_ locale: StoreLocale) -> SuggestionScope {
        .appPrivacy(locale: locale.code)
    }

    /// The App Information page it's on; nil for the Store Page.
    var page: AppInformationPage? {
        switch self {
        case .storePage: nil
        case let .appInformation(page): AppInformationPage(rawValue: page)
        case .accessibility: .accessibility
        case .appPrivacy: .appPrivacy
        }
    }

    static func storePage(_ locale: StoreLocale) -> SuggestionScope {
        .storePage(locale: locale.code)
    }
}
