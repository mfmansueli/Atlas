//
//  AppPreviewSetPush+Editing.swift
//  Atlas
//

import Foundation

// App Previews by hand on the Screenshots language page: the set starts as
// what's live, and each add, replace, delete or move changes the places it
// ends with and the live ones the push deletes. A set takes 3.
extension AppPreviewSetPush.Content {
    typealias Slot = AppPreviewSetPush.Slot
    typealias File = ProductPageScreenshotsPush.File

    static var capacity: Int { ProductPageMedia.appPreviews.limit }

    /// The set as it is live, in order.
    static func start(
        appID: StoreApp.ID, localizationID: String, locale: String, displayType: ScreenshotDisplayType, live: LiveAppPreviewSet?
    ) -> Self {
        let slots = (live?.previews ?? []).map { Slot(liveID: $0.id, fileName: $0.fileName) }
        return Self(appID: appID, localizationID: localizationID, locale: locale, displayType: displayType, slots: slots, deletedIDs: [])
    }

    var hasRoom: Bool { slots.count < Self.capacity }

    /// Adds the files after the last App Preview, as many as fit; how many
    /// went in.
    @discardableResult
    mutating func add(_ files: [File], proposedBy: String? = nil) -> Int {
        let fitting = files.prefix(max(0, Self.capacity - slots.count))
        slots += fitting.map { Slot(fileName: $0.fileName, file: $0, proposedBy: proposedBy) }
        return fitting.count
    }

    /// Puts `file` in place of the App Preview at `index`; a live one is
    /// deleted once the file is processed.
    @discardableResult
    mutating func replace(at index: Int, with file: File, proposedBy: String? = nil) -> Bool {
        guard slots.indices.contains(index) else { return false }
        let old = slots[index]
        let replaced = old.liveID ?? old.replacesID
        if let liveID = old.liveID, !deletedIDs.contains(liveID) { deletedIDs.append(liveID) }
        slots[index] = Slot(fileName: file.fileName, file: file, replacesID: replaced, proposedBy: proposedBy)
        return true
    }

    /// Takes the App Preview at `index` out; a live one is deleted when
    /// the person pushes.
    @discardableResult
    mutating func delete(at index: Int) -> Bool {
        guard slots.indices.contains(index) else { return false }
        let old = slots.remove(at: index)
        if let liveID = old.liveID, !deletedIDs.contains(liveID) { deletedIDs.append(liveID) }
        return true
    }

    /// Swaps it with its neighbor: −1 left, +1 right.
    @discardableResult
    mutating func move(at index: Int, by offset: Int) -> Bool {
        let target = index + offset
        guard slots.indices.contains(index), slots.indices.contains(target) else { return false }
        slots.swapAt(index, target)
        return true
    }

    /// Whether it's what's live: nothing to push.
    func isUnchanged(from live: LiveAppPreviewSet?) -> Bool {
        deletedIDs.isEmpty && slots.allSatisfy { $0.file == nil } && slots.compactMap(\.liveID) == (live?.previews ?? []).map(\.id)
    }

    /// Paths of the files it uploads, so the folder keeps them.
    var filePaths: Set<String> { Set(slots.compactMap(\.file?.path)) }
}
