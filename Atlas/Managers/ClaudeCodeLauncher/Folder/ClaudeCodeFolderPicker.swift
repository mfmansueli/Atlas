//
//  ClaudeCodeFolderPicker.swift
//  Atlas
//

import AppKit

/// Choose…: an app's project folder, where Claude Code starts. The
/// helper runs outside the sandbox and needs only the path; Atlas keeps a
/// bookmark too (`ProjectFolderBookmarks`), to read which links the app
/// claims for In-App Events' deep links.
@MainActor
enum ClaudeCodeFolderPicker {
    static func choose(appName: String, suggestion: String?) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Choose")
        panel.message = String(localized: """
        Choose \(appName)’s project folder. Claude Code starts there, so it can read the code and git history; \
        it never changes it.
        """)
        if let suggestion { panel.directoryURL = URL(filePath: suggestion, directoryHint: .isDirectory) }
        guard panel.runModal() == .OK else { return nil }
        return panel.url?.path(percentEncoded: false)
    }
}
