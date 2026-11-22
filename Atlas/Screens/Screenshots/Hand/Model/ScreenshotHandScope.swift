//
//  ScreenshotHandScope.swift
//  Atlas
//

import Foundation

/// Where a replace, delete or add goes: only the language in view, or
/// every language with its own screenshots on that device.
enum ScreenshotHandScope: Hashable, Sendable {
    case one
    case every
}
