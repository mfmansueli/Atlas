//
//  ReviewRiskLanguageCode.swift
//  Atlas
//

import Foundation

/// Language codes from the store ("de-DE", "zh-Hans", "no") and the project
/// ("de", "zh-Hans", "nb", "pt-BR") brought to one form, so a store language
/// and a translation can be compared: the language alone, lowercased, except
/// Chinese, which keeps its script.
enum ReviewRiskLanguageCode {
    static func base(_ code: String) -> String {
        let lower = code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "_", with: "-")
        let parts = lower.split(separator: "-").map(String.init)
        guard let first = parts.first, !first.isEmpty else { return lower }
        if first == "zh" {
            let traditional = parts.dropFirst().contains { ["hant", "tw", "hk", "mo"].contains($0) }
            return traditional ? "zh-hant" : "zh-hans"
        }
        switch first {
        case "no", "nn": return "nb"
        case "iw": return "he"
        default: return first
        }
    }

    /// The language's name in the person's language: "German".
    static func name(_ base: String) -> String {
        Locale.current.localizedString(forIdentifier: base) ?? base
    }
}
