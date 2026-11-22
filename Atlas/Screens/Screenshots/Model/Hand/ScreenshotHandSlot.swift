//
//  ScreenshotHandSlot.swift
//  Atlas
//

import Foundation

/// One place in a set edited by hand: what it started as (nil for a
/// screenshot added by hand), the file that replaces it, and whether it
/// goes when the person pushes.
struct ScreenshotHandSlot: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var base: ScreenshotHandBase?
    /// The file shown in this place instead of the base, or the file added.
    var file: ScreenshotHandFile?
    /// Deleted: shown as "Will be deleted" until the push removes it.
    var isDeleted = false

    init(id: String = UUID().uuidString, base: ScreenshotHandBase?, file: ScreenshotHandFile? = nil, isDeleted: Bool = false) {
        self.id = id
        self.base = base
        self.file = file
        self.isDeleted = isDeleted
    }

    var origin: ScreenshotHandOrigin {
        if let file { return file.copiedFrom.map { .copied(from: $0) } ?? .uploaded }
        switch base {
        case .template: return .template
        case .live, nil: return .live
        }
    }

    /// Replaced, added or deleted: Undo Change has something to undo.
    var isChanged: Bool { file != nil || isDeleted }

    /// Added by hand rather than replacing something.
    var isAdded: Bool { base == nil }
}
