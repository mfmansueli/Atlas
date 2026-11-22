//
//  ScreenshotHandCellInfo.swift
//  Atlas
//

import Foundation

/// What a cell of a set changed by hand knows about its place: which one
/// it is, where its image comes from and the file in it, for the
/// selection bar, Undo Change and the sheets.
struct ScreenshotHandCellInfo: Hashable, Sendable {
    var slotID: String
    /// Its place among every one of the set's places, deleted ones too.
    var index: Int
    var origin: ScreenshotHandOrigin
    var file: ScreenshotHandFile?
    var isAdded: Bool
    var isDeleted: Bool

    /// Replaced, added or deleted: Undo Change shows.
    var isChanged: Bool { file != nil || isDeleted }

    init(slot: ScreenshotHandSlot, index: Int) {
        slotID = slot.id
        self.index = index
        origin = slot.origin
        file = slot.file
        isAdded = slot.isAdded
        isDeleted = slot.isDeleted
    }
}
