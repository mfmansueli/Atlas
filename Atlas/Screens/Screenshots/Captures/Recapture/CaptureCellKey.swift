//
//  CaptureCellKey.swift
//  Atlas
//

import Foundation

/// One cell of Screenshots → Captures: a language's slot on a device, as
/// the selection, Replace… and Capture Again with Claude Code name it.
struct CaptureCellKey: Hashable, Sendable {
    var locale: String
    var displayType: ScreenshotDisplayType
    var slot: Int
}
