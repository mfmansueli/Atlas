//
//  ScreenshotHandBase.swift
//  Atlas
//

import Foundation

/// What a slot of a set edited by hand started as: a slot the template
/// renders (in a language Atlas makes screenshots for), or a screenshot
/// that's live in App Store Connect (in a language or on a device Atlas
/// doesn't render), remembered by its ID so moving it never re-uploads it.
enum ScreenshotHandBase: Codable, Hashable, Sendable {
    case template(slot: Int)
    case live(id: String, fileName: String, checksum: String?)

    var templateSlot: Int? {
        if case let .template(slot) = self { return slot }
        return nil
    }

    var liveID: String? {
        if case let .live(id, _, _) = self { return id }
        return nil
    }
}
