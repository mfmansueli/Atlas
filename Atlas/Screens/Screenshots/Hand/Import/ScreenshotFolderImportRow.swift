//
//  ScreenshotFolderImportRow.swift
//  Atlas
//

import Foundation

/// One language and device found in an imported folder: its files in
/// order, or why it's skipped.
struct ScreenshotFolderImportRow: Identifiable, Hashable, Sendable {
    /// The folder's name for the language ("de-DE"), or what was there.
    let folderName: String
    /// The store page's locale it matches; nil when it doesn't.
    let localeCode: String?
    /// "German", or the folder's name when it isn't a language on the page.
    let languageName: String
    let displayType: ScreenshotDisplayType?
    /// The files that go, in order.
    let files: [ScreenshotHandChosenFile]
    /// Files left out and why, e.g. "IMG_0412.PNG: wrong size".
    let skippedFiles: [String]
    /// Why the whole row is skipped; nil when it goes.
    let problem: String?

    var id: String { "\(folderName)|\(displayType?.rawValue ?? "-")" }

    var isReady: Bool { problem == nil && localeCode != nil && displayType != nil && !files.isEmpty }
}
