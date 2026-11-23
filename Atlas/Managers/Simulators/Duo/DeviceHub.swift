//
//  DeviceHub.swift
//  Atlas
//

import AppKit

/// Xcode's Device Hub, where iPhone Duo is opened. Its simulator starts
/// closed, with apps on its 1398 × 2034 cover display and the inner display
/// black, and no command opens it: `simctl`, `devicectl` and XCTest only
/// read the hinge. The Duo's own window in Device Hub has its poses
/// (Closed, Partially Open, Open) and the hinge; a `devices://device/open`
/// link shows that window. Atlas's helper presses Open there itself
/// (`DuoWatcher`); these are for when it can't.
enum DeviceHub {
    static let bundleIdentifier = "com.apple.dt.Devices"

    /// What the person does, for the sheet: open it.
    static let openingSteps = String(localized: """
    In Device Hub, pick the Open pose or drag iPhone Duo’s hinge fully open. Keep it running: a restart closes it.
    """)

    /// What the person does when its SpringBoard is stuck (a spinner on the
    /// inner display) and Atlas can't restart it (`DuoWatcher`).
    static let restartSteps = String(localized: """
    Only a spinner? In Device Hub: shut it down, start it, wait for the Home Screen, open it.
    """)

    /// Where it is, or nil when this Mac's Xcode has none.
    @MainActor
    static var url: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    /// The link that shows a simulator's own window, with its poses.
    static func windowLink(for udid: String) -> URL? {
        var components = URLComponents()
        components.scheme = "devices"
        components.host = "device"
        components.path = "/open"
        components.queryItems = [URLQueryItem(name: "id", value: udid)]
        return components.url
    }

    /// Device Hub, on the simulator's own window when there's one.
    @MainActor
    static func open(udid: String? = nil) {
        if let udid, let link = windowLink(for: udid), NSWorkspace.shared.open(link) { return }
        guard let url else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
