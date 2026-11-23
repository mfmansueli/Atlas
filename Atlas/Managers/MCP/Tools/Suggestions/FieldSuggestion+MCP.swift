//
//  FieldSuggestion+MCP.swift
//  Atlas
//

import Foundation

extension FieldSuggestion {
    /// As `get_store_page` and `get_app_information` list open suggestions,
    /// so an assistant doesn't send the same thing again.
    var mcpJSON: JSONValue {
        var entry: [String: JSONValue] = [
            "id": .string(id),
            "field": .string(target.field),
            "value": .string(value),
            "reason": .string(reason),
            "source": .string(source.title),
        ]
        layers?.add(to: &entry)
        switch target.scope {
        case let .storePage(locale): entry["locale"] = .string(locale)
        case let .appInformation(page): entry["page"] = .string(SuggestFieldsTool.mcpPageName(page))
        case let .accessibility(family):
            entry["page"] = .string(AppInformationPage.accessibility.rawValue)
            entry["device"] = .string(DeviceFamily(rawValue: family)?.mcpName ?? family)
        case let .appPrivacy(locale):
            entry["page"] = .string(AppInformationPage.appPrivacy.rawValue)
            entry["locale"] = .string(locale)
        }
        return .object(entry)
    }
}
