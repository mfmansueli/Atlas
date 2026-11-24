//
//  ProductPageVideoFilePanel.swift
//  Atlas
//

import AppKit
import UniformTypeIdentifiers

/// Choose App Previews…' open panel: MOV, MP4 or M4V videos for one
/// language of a page (or of the version, on the Screenshots language
/// page), on one device, in name order.
@MainActor
enum ProductPageVideoFilePanel {
    static func choose(pageName: String, language: String, device: ProductPageDevice) -> [URL]? {
        guard let spec = AppPreviewSpec.spec(for: device.displayType, landscape: false) else { return nil }
        let panel = NSOpenPanel()
        panel.title = String(localized: "App Previews for “\(pageName)”")
        let size = "\(spec.pixelSize.width) × \(spec.pixelSize.height)"
        panel.message = String(
            localized: "Choose up to 3 \(device.displayType.title) App Previews for \(language): \(size), 15 to 30 seconds. Only this page changes."
        )
        panel.prompt = String(localized: "Add to Page")
        return run(panel, multiple: true)
    }

    /// The version's App Previews by hand: up to the room left, or one in
    /// place of App Preview `replacing` (from 0).
    static func choose(language: String, displayType: ScreenshotDisplayType, room: Int, replacing: Int?) -> [URL]? {
        guard let spec = AppPreviewSpec.spec(for: displayType, landscape: false) else { return nil }
        let panel = NSOpenPanel()
        let size = "\(spec.pixelSize.width) × \(spec.pixelSize.height)"
        if let replacing {
            panel.title = String(localized: "Replace App Preview \(replacing + 1)", comment: "kind:title")
            panel.message = String(localized: "One \(displayType.title) video for \(language): \(size), 15 to 30 seconds.", comment: "kind:body")
            panel.prompt = String(localized: "Replace", comment: "kind:button")
        } else {
            panel.title = String(localized: "App Previews for \(language)", comment: "kind:title")
            panel.message = String(
                localized: "Choose up to \(room) \(displayType.title) videos: \(size), 15 to 30 seconds, MOV, MP4 or M4V.", comment: "kind:body"
            )
            panel.prompt = String(localized: "Add", comment: "kind:button")
        }
        return run(panel, multiple: replacing == nil)
    }

    private static func run(_ panel: NSOpenPanel, multiple: Bool) -> [URL]? {
        panel.allowsMultipleSelection = multiple
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.quickTimeMovie, .mpeg4Movie, .appleProtectedMPEG4Video, UTType("com.apple.m4v-video")].compactMap(\.self)
        guard panel.runModal() == .OK else { return nil }
        return panel.urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
