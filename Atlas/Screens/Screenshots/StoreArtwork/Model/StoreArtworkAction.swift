//
//  StoreArtworkAction.swift
//  Atlas
//

import Foundation

/// What a header or search tile's menu does.
enum StoreArtworkAction: Hashable, Sendable {
    /// Add Header… or Add Search Artwork…: a PNG or JPEG.
    case add
    /// Make with Autopilot…: Claude Design, in the app's look.
    case makeWithAutopilot
    case replace
    /// Make a New One…: Autopilot again.
    case makeNew
    case delete
    /// Back to what's on the App Store.
    case undo
}
