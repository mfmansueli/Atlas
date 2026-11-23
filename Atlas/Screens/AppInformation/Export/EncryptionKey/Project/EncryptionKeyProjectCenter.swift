//
//  EncryptionKeyProjectCenter.swift
//  Atlas
//

import Foundation
import Observation

/// What each app's project says about the export compliance key, read
/// when Export Compliance opens and again when the project folder changes,
/// a report arrives or Check Again is asked; `get_export_compliance` reads
/// what was last read.
@MainActor
@Observable
final class EncryptionKeyProjectCenter {
    static let shared = EncryptionKeyProjectCenter()

    private(set) var states: [StoreApp.ID: EncryptionKeyProjectState] = [:]
    @ObservationIgnored private var readRevisions: [StoreApp.ID: Int] = [:]
    @ObservationIgnored private var pinned: Set<StoreApp.ID> = []

    func state(for appID: StoreApp.ID) -> EncryptionKeyProjectState {
        states[appID] ?? .unknown
    }

    /// Reads `app`'s project folder, unless it was read since it last
    /// changed; `force` reads it anyway.
    func refresh(_ app: StoreApp, launcher: ClaudeCodeLauncher, force: Bool = false) async {
        guard !pinned.contains(app.id) else { return }
        let revision = launcher.projectFolderRevision
        guard force || states[app.id] == nil || readRevisions[app.id] != revision else { return }
        guard launcher.projectFolder(for: app.id) != nil else {
            states[app.id] = .noFolder
            readRevisions[app.id] = revision
            return
        }
        let bundleID = app.bundleID
        let state = await launcher.readProjectFolder(for: app.id) { folder in
            EncryptionKeyProjectReader.read(folder: folder, bundleID: bundleID)
        }
        states[app.id] = state ?? .noFolder
        readRevisions[app.id] = revision
    }

    /// Tests and DEBUG scenes: the app's project as given (no folder is
    /// read for it).
    func pin(_ state: EncryptionKeyProjectState, for appID: StoreApp.ID) {
        states[appID] = state
        pinned.insert(appID)
    }
}
