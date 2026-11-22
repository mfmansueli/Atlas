//
//  ScreenshotFolderImportMode.swift
//  Atlas
//

import Foundation

/// What Import a Folder does with each language in the folder.
enum ScreenshotFolderImportMode: Hashable, Sendable {
    /// Its current screenshots are deleted when you push.
    case replace
    /// After its screenshots, up to 10.
    case add
}
