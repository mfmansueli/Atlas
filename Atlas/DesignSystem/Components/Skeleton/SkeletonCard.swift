//
//  SkeletonCard.swift
//  Atlas
//

import SwiftUI

/// A card's shape while its data loads (a11y-loading, Overview's cards,
/// review and nomination cards): the card itself, a title line and a few
/// text lines, static and grey.
struct SkeletonCard: View {
    /// The card's height; nil lets the lines decide.
    var height: CGFloat? = Metrics.skeletonCardHeight
    /// Text lines under the title.
    var lines = 3

    var body: some View {
        Card {
            SkeletonLine(fraction: SkeletonPattern.cardTitle, height: Metrics.skeletonTitleLine)
            ForEach(0..<max(lines, 0), id: \.self) { line in
                SkeletonLine(fraction: SkeletonPattern.cardFraction(line: line), height: Metrics.skeletonBodyLine)
            }
            // A fixed height is the card's own, not only its slot's.
            if height != nil { Spacer(minLength: 0) }
        }
        .frame(height: height, alignment: .top)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        SkeletonCard()
        SkeletonCard(height: nil, lines: 2)
    }
    .padding()
    .frame(width: 600)
}
