//
//  RootView.swift
//  Atlas
//

import SwiftUI

/// The main window's content: Welcome and Connect until an API key is
/// saved, the app library of the key in use after, and the "Add Another
/// Key…" sheet. A DEBUG launch with `-AtlasDebugScene <id>` shows a canned
/// scene instead (`DebugScene`).
struct RootView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.keyChecker) private var keyChecker
    /// Nil in previews.
    @Environment(BackgroundWork.self) private var background: BackgroundWork?
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var session = session
        Group {
            #if DEBUG
            if let id = DebugScene.requestedID {
                DebugSceneView(id: id)
            } else {
                content
            }
            #else
            content
            #endif
        }
        .sheet(isPresented: $session.isAddingKey) {
            AddKeySheet()
        }
        // The menu bar's Open Atlas and Settings…, and the close button
        // that hides this window instead of closing it.
        .background(MainWindowAccessor { AtlasLifecycle.shared.windows.attach($0) })
        .task {
            AtlasLifecycle.shared.openSettings = { openSettings() }
            AtlasLifecycle.shared.openMainWindow = { openWindow(id: "main") }
        }
        .onChange(of: session.credentials == nil) { _, isSignedOut in
            if isSignedOut { background?.detach() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let credentials = session.credentials {
            MainView(
                credentials: credentials,
                accounts: session.accounts,
                isFirstSync: session.firstSyncKeyID == credentials.keyID,
                onSelectAccount: { session.select(keyID: $0.keyID) },
                onAddKey: { session.isAddingKey = true },
                onFirstSyncFinished: session.finishFirstSync,
                onCancelFirstSync: { try? session.cancelFirstSync() },
                onTeamNameFound: { session.recordTeamName($0, for: credentials.keyID) }
            )
            // A different key is a different account: start over.
            .id(credentials)
        } else {
            WelcomeFlowView(checker: keyChecker, notice: session.loadErrorMessage) { try session.connect($0, check: $1) }
        }
    }
}
