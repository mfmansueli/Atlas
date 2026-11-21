//
//  ProductPageVideoFilePanel.swift
//  Atlas
//

import AppKit
import UniformTypeIdentifiers

/// Choose App Previews…' open panel: MOV, MP4 or M4V videos for one
/// language of a page, on one device, in name order.
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
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.quickTimeMovie, .mpeg4Movie, .appleProtectedMPEG4Video, UTType("com.apple.m4v-video")].compactMap(\.self)
        guard panel.runModal() == .OK else { return nil }
        return panel.urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
