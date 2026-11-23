//
//  AddedKey.swift
//  Atlas
//

import Foundation

/// Another team's key that "Add Another Key…" just saved, for its done
/// step: which team it opens, its apps, and the team that stays in use.
struct AddedKey: Equatable, Sendable {
    var keyID: String
    /// Nil when App Store Connect didn't name the team.
    var teamName: String?
    var appCount: Int
    var appNames: [String]
    /// The team the main window stays on until the person switches.
    var keptTeam: String

    init(keyID: String, check: KeyAccessCheck, keptTeam: String) {
        self.keyID = keyID
        teamName = check.teamName
        appCount = check.appCount
        appNames = check.appNames ?? []
        self.keptTeam = keptTeam
    }

    /// How many names the line lists before "+ 3 more".
    static let listedNames = 3

    /// "Fieldworks Studio is connected".
    var title: String {
        guard let teamName else { return String(localized: "The new key is connected", comment: "kind:done-state") }
        return String(localized: "\(teamName) is connected", comment: "kind:done-state")
    }

    /// "Its 3 apps are in the app switcher, under their own team. Atlas
    /// stays in Northpier Studio until you switch."
    var message: String {
        let apps = switch appCount {
        case 0: String(localized: "It has no apps yet.", comment: "kind:done-state")
        case 1: String(localized: "Its app is in the app switcher, under its own team.", comment: "kind:done-state")
        default: String(localized: "Its \(appCount) apps are in the app switcher, under their own team.", comment: "kind:done-state")
        }
        return apps + " " + String(localized: "Atlas stays in \(keptTeam) until you switch.", comment: "kind:done-state")
    }

    /// "3 of 3 · Trailhead, Ledgerly, Kiln", or nil without names.
    var appsLine: String? {
        guard !appNames.isEmpty else { return nil }
        var names = appNames.prefix(Self.listedNames).joined(separator: ", ")
        if appNames.count > Self.listedNames {
            names += " " + String(localized: "+ \(appNames.count - Self.listedNames) more", comment: "kind:label")
        }
        return String(localized: "\(appCount) of \(appCount) · \(names)", comment: "kind:done-state")
    }

    /// "Keep Northpier Studio".
    var keepTitle: String {
        String(localized: "Keep \(keptTeam)", comment: "kind:button")
    }

    /// "Switch to Fieldworks Studio".
    var switchTitle: String {
        guard let teamName else { return String(localized: "Switch to the New Key", comment: "kind:button") }
        return String(localized: "Switch to \(teamName)", comment: "kind:button")
    }
}
