//
//  ToolbarLabelRoom.swift
//  Atlas
//

import SwiftUI

/// Measures, out of sight, how much wider a toolbar button is with its
/// label than folded to its icon, and reports it (`reportToolbarRoom`), so
/// the toolbar folds labels only when they don't fit. Goes in the button's
/// background, where it takes no room.
struct ToolbarLabelRoom<Full: View, Folded: View>: View {
    let item: ToolbarRoomItem
    let full: Full
    let folded: Folded

    @Environment(\.reportToolbarRoom) private var report
    @State private var fullWidth: CGFloat = 0
    @State private var foldedWidth: CGFloat = 0

    var body: some View {
        ZStack {
            full
                .fixedSize()
                .onGeometryChange(for: CGFloat.self, of: \.size.width) { fullWidth = $0 }
            folded
                .fixedSize()
                .onGeometryChange(for: CGFloat.self, of: \.size.width) { foldedWidth = $0 }
        }
        .hidden()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: Self.extra(full: fullWidth, folded: foldedWidth), initial: true) { _, extra in
            if let extra { report(item, extra) }
        }
        .onDisappear { report(item, 0) }
    }

    /// The label's own width; nil before both forms are measured.
    nonisolated static func extra(full: CGFloat, folded: CGFloat) -> CGFloat? {
        guard full > 0, folded > 0 else { return nil }
        return max(0, (full - folded).rounded(.up))
    }
}
