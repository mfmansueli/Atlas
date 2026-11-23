//
//  AccountsSheetText.swift
//  Atlas
//

import Foundation

/// The words of Accounts and keys and Add App that depend on the account.
enum AccountsSheetText {
    /// “Admin · key 2X9R4HXF34 · 6 apps”; the apps only when known.
    static func detail(for account: TeamAccount, appCount: Int?) -> String {
        var parts = [account.role, String(localized: "key \(account.keyID)", comment: "kind:description")]
        if let appCount {
            parts.append(appCount == 1
                ? String(localized: "1 app", comment: "kind:description")
                : String(localized: "\(appCount) apps", comment: "kind:description"))
        }
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// “Apps in Northpier Studio that Atlas doesn’t show yet.”
    static func addAppSubtitle(team: String?) -> String {
        guard let team else { return String(localized: "Apps in this team that Atlas doesn’t show yet.", comment: "kind:sheet-body") }
        return String(localized: "Apps in \(team) that Atlas doesn’t show yet.", comment: "kind:sheet-body")
    }

    /// When every app of the team is already in the menu.
    static func addAppEmpty(team: String?) -> String {
        guard let team else { return String(localized: "Every app in this team is already in Atlas.", comment: "kind:empty-state") }
        return String(localized: "Every app in \(team) is already in Atlas.", comment: "kind:empty-state")
    }

    /// The toast after Add: “Pebble Weather is in the app menu.”
    static func added(_ app: StoreApp) -> String {
        String(localized: "\(app.name) is in the app menu. Reading its store page, screenshots and prices…", comment: "kind:toast")
    }
}
