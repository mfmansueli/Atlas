//
//  AppSwitcherSummary.swift
//  Atlas
//

import Foundation

/// The app switcher's last line (board 63): how many other apps there are
/// and, in purple, which of them have suggestions waiting. "5 other apps ·
/// 2 with suggestions", "1 other app · 3 suggestions in Habitat", or just
/// "5 other apps"; nothing with no other app.
struct AppSwitcherSummary: Equatable, Sendable {
    /// "5 other apps"; empty with no other app.
    let othersText: String
    /// " · 2 with suggestions", the purple part; empty when none has any.
    let suggestionsText: String

    /// - Parameter others: every app but the one being viewed, with its
    ///   count of suggestions to review.
    init(others: [(name: String, suggestionCount: Int)]) {
        switch others.count {
        case 0: othersText = ""
        case 1: othersText = String(localized: "1 other app")
        default: othersText = String(localized: "\(others.count) other apps")
        }
        let suggesting = others.filter { $0.suggestionCount > 0 }
        switch suggesting.count {
        case 0:
            suggestionsText = ""
        case 1:
            let only = suggesting[0]
            // "Lumen — Daily Journal" reads "Lumen".
            let name = only.name.components(separatedBy: " — ").first ?? only.name
            suggestionsText = only.suggestionCount == 1
                ? String(localized: " · 1 suggestion in \(name)")
                : String(localized: " · \(only.suggestionCount) suggestions in \(name)")
        default:
            suggestionsText = String(localized: " · \(suggesting.count) with suggestions")
        }
    }

    /// Whether the switcher shows the line at all.
    var hasOthers: Bool { !othersText.isEmpty }

    /// "5 other apps · 2 with suggestions".
    var line: String { othersText + suggestionsText }

    /// "App: Lumen Journal. 5 other apps · 2 with suggestions. Switch app";
    /// the team is the switcher's value.
    func accessibilityLabel(appName: String?) -> String {
        guard let appName else { return String(localized: "Switch app") }
        return hasOthers
            ? String(localized: "App: \(appName). \(line). Switch app")
            : String(localized: "App: \(appName). Switch app")
    }
}
