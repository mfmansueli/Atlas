//
//  SkeletonPattern.swift
//  Atlas
//

import CoreGraphics

/// The widths a skeleton's lines take, row after row: varied enough that
/// rows read as text still coming, the same on every draw, so nothing
/// moves while the data loads (Motion v2: a skeleton never animates).
enum SkeletonPattern {
    /// The first line of each row (a name, a title).
    static let primary: [CGFloat] = [0.7, 0.55, 0.65, 0.5, 0.6, 0.45]
    /// The second, shorter line (a detail, a bundle ID).
    static let secondary: [CGFloat] = [0.5, 0.4, 0.45, 0.35, 0.42, 0.3]
    /// A card's lines under its title (README · a11y-loading).
    static let card: [CGFloat] = [0.7, 0.85, 0.55, 0.75]
    /// A card's title line.
    static let cardTitle: CGFloat = 0.4

    /// Row `row`'s line `line` (0 the first, 1 the second), wrapping
    /// around the pattern.
    static func fraction(row: Int, line: Int) -> CGFloat {
        let widths = line == 0 ? primary : secondary
        return widths[((row % widths.count) + widths.count) % widths.count]
    }

    /// A card's line `line` under its title.
    static func cardFraction(line: Int) -> CGFloat {
        card[((line % card.count) + card.count) % card.count]
    }

    /// A share of a width, kept to 0…1.
    static func clamped(_ fraction: CGFloat) -> CGFloat {
        guard fraction.isFinite else { return 0 }
        return min(1, max(0, fraction))
    }
}
