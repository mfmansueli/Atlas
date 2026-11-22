//
//  ScreenshotHandFilePanel.swift
//  Atlas
//

import AppKit
import UniformTypeIdentifiers

/// The open panels of Screenshots by hand: PNG or JPEG files for one
/// language's set, or a folder of screenshots for several.
@MainActor
enum ScreenshotHandFilePanel {
    static func chooseFiles(display: ScreenshotDisplayType, language: String, multiple: Bool) -> [ScreenshotHandChosenFile]? {
        let panel = NSOpenPanel()
        panel.title = multiple ? String(localized: "Add Screenshots") : String(localized: "Replace Screenshot")
        panel.message = String(
            localized: "\(display.title) screenshots for \(language): \(ScreenshotHandSizes.all(on: display)), PNG or JPEG without transparency."
        )
        panel.prompt = multiple ? String(localized: "Choose") : String(localized: "Choose File")
        panel.allowsMultipleSelection = multiple
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg]
        guard panel.runModal() == .OK else { return nil }
        return ScreenshotHandDrop.files(from: panel.urls)
    }

    static func chooseFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Import a Folder")
        panel.message = String(localized: "Choose a folder with a folder per language, as fastlane names them (de-DE/iphone-6.9/01.png).")
        panel.prompt = String(localized: "Choose Folder")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
