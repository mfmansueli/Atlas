//
//  MCPBridgeAppLauncher.swift
//  atlas-mcp
//

import AppKit

/// Opens the Atlas.app the bridge is in (or, run from elsewhere, the one
/// Launch Services knows) in the background, so an assistant started while
/// Atlas was closed still connects.
struct MCPBridgeAppLauncher: MCPBridgeLauncher {
    static let bundleIdentifier = "com.lima.atlas"
    /// An Atlas launched this recently is still starting its server.
    static let startingWindow: TimeInterval = 20

    /// The Atlas.app around the bridge, from
    /// `Atlas.app/Contents/MacOS/atlas-mcp`; nil when it isn't in one.
    let appURL: URL?

    init(executableURL: URL? = Bundle.main.executableURL) {
        let app = executableURL?.resolvingSymlinksInPath()
            .deletingLastPathComponent() // MacOS
            .deletingLastPathComponent() // Contents
            .deletingLastPathComponent() // Atlas.app
        appURL = app?.pathExtension == "app" ? app : nil
    }

    func openAtlas() async -> MCPBridgeLaunch {
        let launched = await MainActor.run {
            NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier).compactMap(\.launchDate).max()
        }
        if let launched {
            return Date.now.timeIntervalSince(launched) < Self.startingWindow ? .starting : .running
        }
        guard let url = appURL ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleIdentifier) else {
            return .unavailable("Atlas isn’t installed on this Mac.")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        do {
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            return .starting
        } catch {
            return .unavailable("Couldn’t open \(url.path(percentEncoded: false)): \(error.localizedDescription)")
        }
    }
}
