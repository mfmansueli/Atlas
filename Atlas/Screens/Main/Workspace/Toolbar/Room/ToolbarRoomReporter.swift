//
//  ToolbarRoomReporter.swift
//  Atlas
//

import SwiftUI

/// Reports a whole toolbar item's width (`reportsToolbarRoom(_:)`): Pro.
struct ToolbarRoomReporter: ViewModifier {
    let item: ToolbarRoomItem

    @Environment(\.reportToolbarRoom) private var report

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width.rounded(.up) }, action: { report(item, $0) })
            .onDisappear { report(item, 0) }
    }
}
