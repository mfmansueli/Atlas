//
//  ScreenshotHandOrigin.swift
//  Atlas
//

import Foundation

/// Where a slot's image comes from, for the selection bar's line and the
/// rule that an uploaded slot isn't redrawn by the template.
enum ScreenshotHandOrigin: Hashable, Sendable {
    /// Atlas renders it from the template and its caption.
    case template
    /// It's live in App Store Connect and Atlas doesn't render it.
    case live
    /// The person gave the file.
    case uploaded
    /// Start from English (U.S.) copied it from that language.
    case copied(from: String)
}
