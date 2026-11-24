//
//  SideColumnLayout.swift
//  Atlas
//

import SwiftUI

/// A page's content with a fixed-width column beside it (Age Rating's
/// rating preview, Overview's App Store page). When the content would get
/// narrower than `minimumMainWidth`, or than it can be, the column goes
/// above it (or below, `stacksSideBelow`) at full width instead of pushing
/// the page wider than the window. It decides from the width it's offered,
/// never from one measured after the fact, which the side-by-side minimum
/// would keep too wide to ever stack. Both children keep their identity
/// either way, so their state survives a resize.
///
/// Takes two children: the content, then the column. The content alone
/// (no column yet) takes the whole width.
struct SideColumnLayout: Layout {
    /// The column's width beside the content.
    var sideWidth: CGFloat
    /// The narrowest the content gets beside the column.
    var minimumMainWidth: CGFloat
    var spacing: CGFloat = Spacing.xLarge
    /// Stacked, the column goes under the content instead of above it.
    var stacksSideBelow = false
    /// Between the two when stacked; nil keeps `spacing`.
    var stackedSpacing: CGFloat?

    /// Whether the column fits beside content that can't be narrower than
    /// `mainMinimumWidth`, in `width`. With no width to fit (an ideal size),
    /// it goes beside.
    func placesBeside(in width: CGFloat?, mainMinimumWidth: CGFloat) -> Bool {
        guard let width else { return true }
        return width - spacing - sideWidth >= max(minimumMainWidth, mainMinimumWidth)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        guard let (main, side) = pair(subviews) else {
            return subviews.first?.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil)) ?? .zero
        }
        if placesBeside(in: proposal.width, mainMinimumWidth: minimumWidth(of: main)) {
            let mainSize = main.sizeThatFits(ProposedViewSize(width: proposal.width.map { $0 - spacing - sideWidth }, height: nil))
            let sideSize = side.sizeThatFits(ProposedViewSize(width: sideWidth, height: nil))
            return CGSize(width: mainSize.width + spacing + sideWidth, height: max(mainSize.height, sideSize.height))
        }
        let stacked = ProposedViewSize(width: proposal.width, height: nil)
        let mainSize = main.sizeThatFits(stacked)
        let sideSize = side.sizeThatFits(stacked)
        return CGSize(width: max(mainSize.width, sideSize.width), height: sideSize.height + (stackedSpacing ?? spacing) + mainSize.height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        guard let (main, side) = pair(subviews) else {
            subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: nil))
            return
        }
        if placesBeside(in: bounds.width, mainMinimumWidth: minimumWidth(of: main)) {
            main.place(
                at: CGPoint(x: bounds.minX, y: bounds.minY),
                proposal: ProposedViewSize(width: bounds.width - spacing - sideWidth, height: nil)
            )
            side.place(at: CGPoint(x: bounds.maxX - sideWidth, y: bounds.minY), proposal: ProposedViewSize(width: sideWidth, height: nil))
        } else {
            let stacked = ProposedViewSize(width: bounds.width, height: nil)
            let tops = stackedTops(mainHeight: main.sizeThatFits(stacked).height, sideHeight: side.sizeThatFits(stacked).height)
            side.place(at: CGPoint(x: bounds.minX, y: bounds.minY + tops.side), proposal: stacked)
            main.place(at: CGPoint(x: bounds.minX, y: bounds.minY + tops.main), proposal: stacked)
        }
    }

    /// Stacked, how far down the content and the column start: the column
    /// first, or under the content with `stacksSideBelow`.
    func stackedTops(mainHeight: CGFloat, sideHeight: CGFloat) -> (main: CGFloat, side: CGFloat) {
        let gap = stackedSpacing ?? spacing
        return stacksSideBelow ? (0, mainHeight + gap) : (sideHeight + gap, 0)
    }

    private func pair(_ subviews: Subviews) -> (main: LayoutSubview, side: LayoutSubview)? {
        guard subviews.count == 2 else { return nil }
        return (subviews[0], subviews[1])
    }

    /// The content's own minimum: its controls that don't wrap.
    private func minimumWidth(of main: LayoutSubview) -> CGFloat {
        main.sizeThatFits(ProposedViewSize(width: 0, height: nil)).width
    }
}

#Preview {
    SideColumnLayout(sideWidth: 200, minimumMainWidth: 240) {
        Text("The questionnaire, as wide as the page allows.")
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(.quaternary)
        Text("Preview")
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
            .background(.tertiary)
    }
    .padding()
    .frame(width: 400)
}
