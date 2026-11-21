//
//  ProductPageScreenshotFilePanel.swift
//  Atlas
//

import AppKit
import UniformTypeIdentifiers

/// Choose Files…' open panel: PNG or JPEG screenshots for one language of
/// a page, on one device, in the order they're chosen.
@MainActor
enum ProductPageScreenshotFilePanel {
    static func choose(pageName: String, language: String, device: ProductPageDevice) -> [URL]? {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Screenshots for “\(pageName)”")
        panel.message = String(
            localized: "Choose up to 10 \(device.displayType.title) screenshots for \(language): \(ProductPageFileCheck.sizesText(device)). Only this page changes."
        )
        panel.prompt = String(localized: "Add to Page")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg]
        guard panel.runModal() == .OK else { return nil }
        return panel.urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}
