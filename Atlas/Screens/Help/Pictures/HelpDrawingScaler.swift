//
//  HelpDrawingScaler.swift
//  Atlas
//

import SwiftUI

/// Lays a drawing out at `Metrics.helpPictureWidth`, the width it's
/// designed at, then scales it to the column (up to
/// `Metrics.helpPictureMaxWidth`), so it keeps its proportions at every
/// window size and never scrolls sideways. The Help window's narrowest
/// column is wider than the design, so no text draws under 10 pt.
struct HelpDrawingScaler<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var width = Metrics.helpPictureWidth
    @State private var height: CGFloat = 0

    var body: some View {
        let scale = width / Metrics.helpPictureWidth
        Color.clear
            .frame(maxWidth: Metrics.helpPictureMaxWidth)
            .frame(height: height * scale)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .overlay(alignment: .topLeading) {
                content
                    .frame(width: Metrics.helpPictureWidth)
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
                    .scaleEffect(scale, anchor: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
