//
//  ScreenshotHandDrop.swift
//  Atlas
//

import Foundation

/// Files dropped on the language page or chosen in a panel, read: PNG and
/// JPEG only, in name order (01, 02, … 10).
enum ScreenshotHandDrop {
    static func files(from urls: [URL]) -> [ScreenshotHandChosenFile] {
        urls
            .filter { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map(ScreenshotHandChosenFile.init(url:))
    }
}
