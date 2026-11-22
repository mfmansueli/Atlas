//
//  LiveAssistantApps.swift
//  Atlas
//

import AppKit

/// The real Claude for Mac and Cursor, through Launch Services, which the
/// sandbox allows: finding an app by its bundle ID, asking it to quit, and
/// opening it (on a folder).
@MainActor
final class LiveAssistantApps: AssistantAppControlling {
    /// How long a quitting app has before Atlas gives up on restarting it.
    var quitTimeout: Duration = .seconds(8)

    func isInstalled(_ assistant: ConnectableAssistant) -> Bool {
        appURL(of: assistant) != nil
    }

    func restart(_ assistant: ConnectableAssistant, folder: URL?) async -> Bool {
        guard let bundleID = assistant.bundleIdentifier, let appURL = appURL(of: assistant) else { return false }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if !running.isEmpty {
            running.forEach { $0.terminate() }
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: quitTimeout)
            while clock.now < deadline, running.contains(where: { !$0.isTerminated }) {
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard running.allSatisfy(\.isTerminated) else { return false }
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        do {
            if let folder {
                _ = try await NSWorkspace.shared.open([folder], withApplicationAt: appURL, configuration: configuration)
            } else {
                _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
            }
            return true
        } catch {
            return false
        }
    }

    func open(_ assistant: ConnectableAssistant) {
        guard let appURL = appURL(of: assistant) else {
            NSWorkspace.shared.open(assistant.downloadURL)
            return
        }
        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    private func appURL(of assistant: ConnectableAssistant) -> URL? {
        assistant.bundleIdentifier.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
    }
}
