//
//  ScreenshotHandPageItem.swift
//  Atlas
//

import Foundation

/// One screenshot as the language page lists it: its cell, its number in
/// the set (deleted ones included) and whether it's selected.
struct ScreenshotHandPageItem: Identifiable, Hashable {
    let cell: ScreenshotCell
    /// 0-based, among every place shown.
    let position: Int
    let isSelected: Bool

    /// The slot's ID in a set changed by hand, else "#" and the position
    /// (the set as it starts has its places in the same order).
    var id: String { cell.hand?.slotID ?? "#\(position)" }

    var isDeleted: Bool { cell.state == .willBeDeleted }
}
