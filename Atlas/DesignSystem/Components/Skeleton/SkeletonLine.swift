//
//  SkeletonLine.swift
//  Atlas
//

import SwiftUI

/// One grey text line of a skeleton, a share of the width it's offered:
/// `SkeletonLine(fraction: 0.7)` is a line 70% as wide as its row. It
/// never asks for width of its own, so a skeleton can't widen a page past
/// the window's minimum.
struct SkeletonLine: View {
    /// How much of the offered width the line covers, 0…1.
    var fraction: CGFloat = 1
    var height: CGFloat = Metrics.skeletonLine

    var body: some View {
        FractionWidth(fraction: fraction) {
            SkeletonBlock(height: height, cornerRadius: Radius.flag)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    /// Takes the whole offered width and gives its content `fraction` of
    /// it, at the leading edge.
    private struct FractionWidth: Layout {
        let fraction: CGFloat

        /// The width a line takes where nothing proposes one, e.g. in a
        /// horizontal stack's ideal size.
        private static let idealWidth: CGFloat = 200

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
            let height = subviews.first?.sizeThatFits(.unspecified).height ?? 0
            return CGSize(width: Self.available(proposal.width), height: proposal.height ?? height)
        }

        func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
            let width = (bounds.width * SkeletonPattern.clamped(fraction)).rounded()
            for subview in subviews {
                subview.place(at: bounds.origin, proposal: ProposedViewSize(width: width, height: bounds.height))
            }
        }

        private static func available(_ width: CGFloat?) -> CGFloat {
            guard let width, width.isFinite else { return idealWidth }
            return max(0, width)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.small) {
        SkeletonLine(fraction: 0.7)
        SkeletonLine(fraction: 0.5, height: Metrics.skeletonCaptionLine)
    }
    .padding()
    .frame(width: 300)
}
