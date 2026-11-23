//
//  ScreenshotHandSet.swift
//  Atlas
//

import Foundation

/// A language's screenshots on one device as the person arranged them by
/// hand: every place in order, what each started as, the files that
/// replace or add to them, and the ones that go. It's the set's makeup
/// from the first edit on, pushed or not; whether something waits for
/// Review & Push is derived by comparing it with what's live.
struct ScreenshotHandSet: Codable, Hashable, Sendable, Identifiable {
    /// The most screenshots a set holds.
    static let capacity = 10

    var locale: String
    var displayType: ScreenshotDisplayType
    /// Every place, in order, the deleted ones included until they're gone.
    var slots: [ScreenshotHandSlot]

    var id: String { Self.key(locale: locale, displayType: displayType) }

    static func key(locale: String, displayType: ScreenshotDisplayType) -> String {
        "\(locale)|\(displayType.rawValue)"
    }

    /// The places that stay after a push, in order.
    var kept: [ScreenshotHandSlot] { slots.filter { !$0.isDeleted } }

    var keptCount: Int { kept.count }

    /// Room for this many more.
    var room: Int { max(0, Self.capacity - keptCount) }

    func index(of slotID: String) -> Int? {
        slots.firstIndex { $0.id == slotID }
    }

    // MARK: - Starting

    /// The set as it is before any edit: the template's slots, or the live
    /// screenshots in their order.
    static func starting(locale: String, displayType: ScreenshotDisplayType, bases: [ScreenshotHandBase]) -> ScreenshotHandSet {
        ScreenshotHandSet(locale: locale, displayType: displayType, slots: bases.map { ScreenshotHandSlot(base: $0) })
    }

    /// Nothing changed from `bases`: the set is the template's (or what's
    /// live) again, and the edit can be forgotten.
    func isUnchanged(from bases: [ScreenshotHandBase]) -> Bool {
        slots.allSatisfy { !$0.isChanged } && slots.map(\.base) == bases
    }

    // MARK: - Editing

    /// Puts `file` in place of the slot's image. Returns false when the
    /// slot isn't there or is deleted.
    @discardableResult
    mutating func replace(_ slotID: String, with file: ScreenshotHandFile) -> Bool {
        guard let index = index(of: slotID), !slots[index].isDeleted else { return false }
        slots[index].file = file
        return true
    }

    /// Replaces the slot at `position` among the kept ones (for another
    /// language's screenshot in the same place).
    @discardableResult
    mutating func replace(position: Int, with file: ScreenshotHandFile) -> Bool {
        let kept = kept
        guard kept.indices.contains(position) else { return false }
        return replace(kept[position].id, with: file)
    }

    /// Marks the slot to go; one added by hand just goes.
    @discardableResult
    mutating func delete(_ slotID: String) -> Bool {
        guard let index = index(of: slotID), !slots[index].isDeleted else { return false }
        if slots[index].isAdded {
            slots.remove(at: index)
        } else {
            slots[index].file = nil
            slots[index].isDeleted = true
        }
        return true
    }

    @discardableResult
    mutating func delete(position: Int) -> Bool {
        let kept = kept
        guard kept.indices.contains(position) else { return false }
        return delete(kept[position].id)
    }

    /// Every screenshot goes.
    mutating func deleteAll() {
        for slot in slots where !slot.isDeleted {
            delete(slot.id)
        }
    }

    /// Adds files after the last place, as many as there's room for.
    /// Returns how many went in.
    @discardableResult
    mutating func add(_ files: [ScreenshotHandFile]) -> Int {
        let taken = Array(files.prefix(room))
        slots += taken.map { ScreenshotHandSlot(base: nil, file: $0) }
        return taken.count
    }

    /// Moves the slot one place left (−1) or right (+1). Returns false at
    /// either end.
    @discardableResult
    mutating func move(_ slotID: String, by offset: Int) -> Bool {
        guard let index = index(of: slotID) else { return false }
        let target = index + offset
        guard slots.indices.contains(target) else { return false }
        slots.swapAt(index, target)
        return true
    }

    /// Swaps two places: what the language page's ◀ ▶ do, past places it
    /// doesn't show.
    @discardableResult
    mutating func swap(_ first: String, _ second: String) -> Bool {
        guard let left = index(of: first), let right = index(of: second), left != right else { return false }
        slots.swapAt(left, right)
        return true
    }

    /// Puts the kept places in `order` (every kept slot's ID, once each);
    /// deleted places stay where they are until they're gone. Returns false
    /// when `order` doesn't name exactly the kept places.
    @discardableResult
    mutating func arrange(_ order: [String]) -> Bool {
        let keptIDs = kept.map(\.id)
        guard order.count == keptIDs.count, Set(order) == Set(keptIDs) else { return false }
        var next = order.compactMap { id in slots.first { $0.id == id } }.makeIterator()
        for index in slots.indices where !slots[index].isDeleted {
            guard let slot = next.next() else { return false }
            slots[index] = slot
        }
        return true
    }

    /// Undo Change: a replaced slot gets its own image back, a deleted one
    /// stays, one added by hand goes.
    @discardableResult
    mutating func undo(_ slotID: String) -> Bool {
        guard let index = index(of: slotID), slots[index].isChanged else { return false }
        if slots[index].isAdded {
            slots.remove(at: index)
        } else {
            slots[index].file = nil
            slots[index].isDeleted = false
        }
        return true
    }

    /// Forgets deleted places once they're gone from App Store Connect.
    mutating func dropDeleted(_ slotIDs: Set<String>) {
        slots.removeAll { $0.isDeleted && slotIDs.contains($0.id) }
    }

    /// The files the set still uses.
    var fileIDs: Set<String> { Set(slots.compactMap(\.file?.id)) }
}
