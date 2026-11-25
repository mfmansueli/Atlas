//
//  ProductPagesLoadingView.swift
//  Atlas
//

import SwiftUI

/// The first read (cp-loading): what's being read, over the list's rows
/// still loading, static and grey.
struct ProductPagesLoadingView: View {
    let appName: String

    /// The rows' cells, as shares of the row (the prototype's 22 · 12 · 26 · 10 %).
    private static let cells: [CGFloat] = [0.22, 0.12, 0.26, 0.10]
    private static let rows = 6

    var body: some View {
        let message = LoadingCopy.productPages(appName: appName)
        VStack(alignment: .leading, spacing: Spacing.small) {
            if let line = message.line {
                LoadingLine(text: line)
            }
            VStack(spacing: 0) {
                ForEach(0..<Self.rows, id: \.self) { index in
                    // Four equal columns, each line its share of the row.
                    HStack(spacing: Spacing.xxLarge) {
                        ForEach(Array(Self.cells.enumerated()), id: \.offset) { _, share in
                            SkeletonLine(fraction: share * CGFloat(Self.cells.count))
                        }
                    }
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, Spacing.large)
                    if index < Self.rows - 1 { Divider() }
                }
            }
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
            .frame(minHeight: 0, alignment: .top)
            .clipped()
        }
        .loadingSkeleton(message, identifier: "pages.loading")
    }
}

#Preview {
    ProductPagesLoadingView(appName: "Lumen")
        .padding()
        .frame(width: 700)
}
