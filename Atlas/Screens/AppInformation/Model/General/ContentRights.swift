//
//  ContentRights.swift
//  Atlas
//

import Foundation

/// The answer to "Does the app contain, show or access third-party
/// content?" (`contentRightsDeclaration` on the app).
enum ContentRights: String, CaseIterable, Hashable, Sendable {
    case usesThirdPartyContent = "USES_THIRD_PARTY_CONTENT"
    case doesNotUseThirdPartyContent = "DOES_NOT_USE_THIRD_PARTY_CONTENT"

    var title: String {
        switch self {
        case .usesThirdPartyContent: String(localized: "Yes")
        case .doesNotUseThirdPartyContent: String(localized: "No")
        }
    }

    /// An answer by id or name, Yes or No, or true or false, ignoring case
    /// and surrounding spaces; nil when it's none of them.
    static func matching(_ text: String) -> ContentRights? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let match = allCases.first { rights in
            [rights.rawValue, rights.title, rights.englishAnswer].contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        }
        return match ?? ["true": .usesThirdPartyContent, "false": .doesNotUseThirdPartyContent][trimmed.lowercased()]
    }

    /// Yes or No as an assistant may write it, whatever language Atlas is in.
    private var englishAnswer: String {
        self == .usesThirdPartyContent ? "yes" : "no"
    }
}
