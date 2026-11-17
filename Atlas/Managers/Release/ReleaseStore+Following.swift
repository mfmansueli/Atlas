//
//  ReleaseStore+Following.swift
//  Atlas
//

import Foundation

// Following the versions on their way while Atlas is open, and
// what the sidebar says about one before its status is read.
extension ReleaseStore {
    /// How often a version on its way is looked at: 15 minutes.
    static let checkInterval: Double = 15 * 60

    /// Looks once at the versions with App Review, approved or rolling
    /// out, of every app but the selected one (its own model reads it).
    /// Returns what to say about the ones that moved, already posted as
    /// notifications.
    func checkOthers(apps: [StoreApp], except selectedID: StoreApp.ID?, services: any ReleaseServices) async -> [String] {
        var messages: [String] = []
        for appID in appsInFlight where appID != selectedID {
            guard let app = apps.first(where: { $0.id == appID }),
                  let status = try? await services.status(for: app, platform: snapshot(for: appID)?.platform),
                  let moved = note(status, for: appID),
                  let text = ReleaseViewModel.announcement(moved, version: status.version.versionString, appName: app.name)
            else { continue }
            ReleaseNotifier.shared.post(text, appName: app.name, appID: app.id)
            messages.append(text)
        }
        return messages
    }

    /// "Version 1.4 · Not submitted yet": the status once read, else what
    /// was seen last, else what the Store Page's summary knows.
    func summary(for appID: StoreApp.ID, model: ReleaseViewModel?, storePage: StorePageSummary?) -> VersionStatusSummary? {
        model?.summary
            ?? snapshot(for: appID).map { VersionStatusSummary(versionString: $0.versionString, phase: $0.phase) }
            ?? VersionStatusSummary(storePage: storePage)
    }
}
