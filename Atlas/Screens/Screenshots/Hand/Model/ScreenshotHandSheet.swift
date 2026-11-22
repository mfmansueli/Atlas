//
//  ScreenshotHandSheet.swift
//  Atlas
//

import Foundation

/// The sheet the language page shows for a change made by hand.
enum ScreenshotHandSheet: Identifiable, Hashable {
    /// Replace Screenshot n, with a file already dropped on it or not.
    case replace(slotID: String, file: ScreenshotHandChosenFile?)
    case delete(slotID: String)
    case deleteAll
    /// Add Screenshots, with the files dropped on the Add tile.
    case add([ScreenshotHandChosenFile])
    case importFolder

    var id: String {
        switch self {
        case let .replace(slotID, _): "replace|\(slotID)"
        case let .delete(slotID): "delete|\(slotID)"
        case .deleteAll: "deleteAll"
        case .add: "add"
        case .importFolder: "import"
        }
    }
}
