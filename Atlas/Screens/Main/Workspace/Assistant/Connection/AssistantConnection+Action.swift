//
//  AssistantConnection+Action.swift
//  Atlas
//

import Foundation

@MainActor
extension AssistantConnection.Action {
    /// Reconnect… opens setup at the assistant, for a new command; Choose
    /// Folder… asks for `app`'s project folder.
    func perform(for app: StoreApp, navigator: WorkspaceNavigator, launcher: ClaudeCodeLauncher) {
        switch self {
        case .reconnect:
            navigator.assistantSetupMethod = .assistant
            navigator.isAssistantSetupPresented = true
        case .chooseFolder:
            launcher.chooseProjectFolder(for: app.id, appName: app.name)
        }
    }
}
