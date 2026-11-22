//
//  PretendAssistantApps.swift
//  Atlas
//

import Foundation

/// Claude for Mac and Cursor as DEBUG scenes and tests have them: installed
/// or not, and a restart that only records what it was asked, then tells
/// `onRestart` (where a test connects the pretend client).
@MainActor
final class PretendAssistantApps: AssistantAppControlling {
    var installed: Set<ConnectableAssistant>
    /// Whether a restart works.
    var restarts = true
    private(set) var restarted: [(assistant: ConnectableAssistant, folder: URL?)] = []
    private(set) var opened: [ConnectableAssistant] = []
    var onRestart: (@MainActor (ConnectableAssistant) -> Void)?

    init(installed: Set<ConnectableAssistant> = Set(ConnectableAssistant.allCases)) {
        self.installed = installed
    }

    func isInstalled(_ assistant: ConnectableAssistant) -> Bool {
        installed.contains(assistant)
    }

    func restart(_ assistant: ConnectableAssistant, folder: URL?) async -> Bool {
        restarted.append((assistant, folder))
        guard restarts else { return false }
        onRestart?(assistant)
        return true
    }

    func open(_ assistant: ConnectableAssistant) {
        opened.append(assistant)
    }
}
