//
//  ToolbarRoomReport.swift
//  Atlas
//

import CoreGraphics

/// Where the toolbar's items say how much room they take, in the
/// environment (`reportToolbarRoom`). Always equal to another, so a new
/// closure on each workspace update doesn't redraw every item that reads it.
struct ToolbarRoomReport: Equatable {
    var action: @MainActor (ToolbarRoomItem, CGFloat) -> Void = { _, _ in }

    @MainActor
    func callAsFunction(_ item: ToolbarRoomItem, _ width: CGFloat) {
        action(item, width)
    }

    static func == (_: ToolbarRoomReport, _: ToolbarRoomReport) -> Bool { true }
}
