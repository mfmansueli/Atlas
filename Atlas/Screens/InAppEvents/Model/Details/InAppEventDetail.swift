//
//  InAppEventDetail.swift
//  Atlas
//

import Foundation

/// What can change on an event that's still a draft, besides its texts
/// and art: where Open goes, who it's for, how it ranks and its primary
/// language. Each is one attribute of `PATCH /v1/appEvents/{id}`, named as
/// App Store Connect names it.
enum InAppEventDetail: String, CaseIterable, Identifiable, Hashable, Codable, Sendable {
    case deepLink
    case purpose
    case priority
    case primaryLocale

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deepLink: String(localized: "Deep link")
        case .purpose: String(localized: "Purpose")
        case .priority: String(localized: "Priority")
        case .primaryLocale: String(localized: "Primary language")
        }
    }

    /// App Store Connect's value on `event`, as the API writes it
    /// (`alba://event`, `ATTRACT_NEW_USERS`, `HIGH`, `en-US`); nil when it
    /// has none.
    func value(in event: InAppEvent) -> String? {
        let value: String? = switch self {
        case .deepLink: event.deepLink?.trimmingCharacters(in: .whitespacesAndNewlines)
        case .purpose: event.purpose?.rawValue
        case .priority: event.priority.rawValue
        case .primaryLocale: event.primaryLocale
        }
        return value?.isEmpty == true ? nil : value
    }

    /// `value` in words: "Bring back lapsed users", "High", "German".
    func display(_ value: String?, appName: String = "") -> String {
        guard let value, !value.isEmpty else { return String(localized: "Not set") }
        switch self {
        case .deepLink:
            return value
        case .purpose:
            guard let purpose = InAppEventPurpose(rawValue: value) else { return value }
            return appName.isEmpty ? purpose.summary : purpose.title(appName: appName)
        case .priority:
            return InAppEventPriority(rawValue: value)?.title ?? value
        case .primaryLocale:
            return InAppEventChangeBuilder.localeName(value)
        }
    }

    /// Why App Store Connect would refuse `value`, saying how to fix it;
    /// nil when it takes it.
    func problem(_ value: String?, appName: String = "") -> String? {
        guard let value, !value.isEmpty else {
            return self == .deepLink ? nil : String(localized: "Choose a \(title.lowercased()).")
        }
        switch self {
        case .deepLink:
            return InAppEventDeepLink.problem(value, appName: appName)
        case .purpose:
            return InAppEventPurpose(rawValue: value) == nil
                ? String(localized: "“\(value)” isn’t a purpose. Use \(InAppEventPurpose.allCases.map(\.rawValue).formatted(.list(type: .or))).")
                : nil
        case .priority:
            return InAppEventPriority(rawValue: value) == nil ? String(localized: "“\(value)” isn’t a priority. Use HIGH or NORMAL.") : nil
        case .primaryLocale:
            return StoreLocaleCatalog.locale(code: value) == nil
                ? String(localized: "“\(value)” isn’t an App Store language code. Use one like en-US or pt-BR.")
                : nil
        }
    }
}
