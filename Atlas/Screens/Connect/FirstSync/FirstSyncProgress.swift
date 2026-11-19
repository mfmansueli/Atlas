//
//  FirstSyncProgress.swift
//  Atlas
//

import Foundation

/// How far the first sync after connecting a key has come: the app list,
/// then each app's subscriptions, store page and App Information, one app
/// at a time.
struct FirstSyncProgress: Equatable, Sendable {
    /// nil while the app list itself is loading.
    var appCount: Int?
    /// Apps whose summaries have loaded.
    var syncedCount = 0
    /// The team's name once App Store Connect or the person gave it.
    var teamName: String?
    /// The apps read so far, in the library's order.
    var syncedNames: [String] = []

    /// How many names the line under the bar lists before "+ 3 more".
    static let listedNames = 3

    /// 0…1 for the progress bar; the app list counts as the first step.
    var fraction: Double {
        guard let appCount else { return 0 }
        guard appCount > 0 else { return 1 }
        return (1 + Double(min(syncedCount, appCount))) / (1 + Double(appCount))
    }

    /// "Found 6 apps in Northpier Studio. Atlas is reading their store
    /// pages, screenshots and prices. Nothing is changed in App Store
    /// Connect."
    var summary: String {
        let nothingChanges = String(localized: "Nothing is changed in App Store Connect.")
        guard let appCount else {
            return String(localized: "Atlas is reading your team and its apps.") + " " + nothingChanges
        }
        let found = switch (appCount, teamName) {
        case let (1, team?): String(localized: "Found 1 app in \(team).")
        case (1, nil): String(localized: "Found 1 app.")
        case let (count, team?): String(localized: "Found \(count) apps in \(team).")
        case let (count, nil): String(localized: "Found \(count) apps.")
        }
        let reading = appCount == 1
            ? String(localized: "Atlas is reading its store page, screenshots and prices.")
            : String(localized: "Atlas is reading their store pages, screenshots and prices.")
        return [found, reading, nothingChanges].joined(separator: " ")
    }

    /// "3 of 6 · Lumen Journal, Habitat, Tempo", under the bar.
    var detail: String {
        guard let appCount else { return String(localized: "Reading your team and apps…") }
        let count = String(localized: "\(min(syncedCount, appCount)) of \(appCount)")
        guard !syncedNames.isEmpty else { return count }
        var names = syncedNames.prefix(Self.listedNames).joined(separator: ", ")
        if syncedNames.count > Self.listedNames {
            names += " " + String(localized: "+ \(syncedNames.count - Self.listedNames) more")
        }
        return "\(count) · \(names)"
    }
}
