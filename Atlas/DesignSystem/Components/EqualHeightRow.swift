//
//  EqualHeightRow.swift
//  Atlas
//

import SwiftUI

/// Views side by side in equal widths, all as tall as the tallest: each is
/// measured at its column's width with no height proposed, then placed with
/// that height exactly. A view that should fill it (its background, a link
/// at the bottom) takes `maxHeight: .infinity` only inside this row.
///
/// Not an `HStack` with `fixedSize` and `maxHeight: .infinity`: those
/// views grew without limit when the row fell back to a stack, and the page
/// pushed the window's content past its top.
struct EqualHeightRow: Layout {
    var spacing: CGFloat
    /// The narrowest a column asks for when the row's width isn't proposed.
    var minColumnWidth: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let gaps = spacing * CGFloat(subviews.count - 1)
        let width = proposal.width ?? subviews.reduce(gaps) { total, subview in
            total + max(subview.sizeThatFits(.unspecified).width, minColumnWidth)
        }
        let column = columnWidth(width, count: subviews.count)
        let height = subviews.map { $0.sizeThatFits(ProposedViewSize(width: column, height: nil)).height }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let column = columnWidth(bounds.width, count: subviews.count)
        var x = bounds.minX
        for subview in subviews {
            subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: column, height: bounds.height))
            x += column + spacing
        }
    }

    private func columnWidth(_ width: CGFloat, count: Int) -> CGFloat {
        max((width - spacing * CGFloat(count - 1)) / CGFloat(count), 0)
    }
}
