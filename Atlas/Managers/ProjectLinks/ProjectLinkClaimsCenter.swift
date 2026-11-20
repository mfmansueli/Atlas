//
//  ProjectLinkClaimsCenter.swift
//  Atlas
//

import Foundation
import Observation

/// What each app's project claims, read once per project folder and kept
/// for In-App Events and the Submit sheet: read again when the folder
/// changes, or when the person asks (Check Again).
@MainActor
@Observable
final class ProjectLinkClaimsCenter {
    static let shared = ProjectLinkClaimsCenter()

    private(set) var states: [StoreApp.ID: ProjectLinkClaimsState] = [:]
    @ObservationIgnored private var readRevisions: [StoreApp.ID: Int] = [:]
    @ObservationIgnored private var pinned: Set<StoreApp.ID> = []

    func state(for appID: StoreApp.ID) -> ProjectLinkClaimsState {
        states[appID] ?? .unknown
    }

    /// Reads `app`'s project folder, unless it was read since it last
    /// changed; `force` reads it anyway.
    func refresh(_ app: StoreApp, launcher: ClaudeCodeLauncher, force: Bool = false) async {
        guard !pinned.contains(app.id) else { return }
        let revision = launcher.projectFolderRevision
        guard force || states[app.id] == nil || states[app.id] == .unknown || readRevisions[app.id] != revision else { return }
        guard launcher.projectFolder(for: app.id) != nil else {
            states[app.id] = .noFolder
            readRevisions[app.id] = revision
            return
        }
        let bundleID = app.bundleID
        let state = await launcher.readProjectFolder(for: app.id) { folder in
            ProjectLinkClaimsReader.read(folder: folder, bundleID: bundleID)
        }
        states[app.id] = state ?? .noFolder
        readRevisions[app.id] = revision
    }

    /// Tests and DEBUG scenes: what the app's project claims, kept as it
    /// is (no folder is read for it).
    func pin(_ state: ProjectLinkClaimsState, for appID: StoreApp.ID) {
        states[appID] = state
        pinned.insert(appID)
    }
}
