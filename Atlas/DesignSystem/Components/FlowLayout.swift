//
//  FlowLayout.swift
//  Atlas
//

import SwiftUI

/// Lays children out left to right and wraps to a new line when the next one
/// doesn't fit: pill rows, keyword tokens, chips. A child wider than a whole
/// line gets the line's width (a one-line text truncates, a longer one
/// wraps), so the row never holds its page wider than the window.
struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.small
    var lineSpacing: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let rows = arrange(subviews, in: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + CGFloat(max(rows.count - 1, 0)) * (lineSpacing ?? spacing)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, in: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = fittedSize(of: subviews[index], in: bounds.width)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + (lineSpacing ?? spacing)
        }
    }

    /// A child's own size, or its size at the line's width when it's wider.
    private func fittedSize(of subview: LayoutSubview, in lineWidth: CGFloat) -> CGSize {
        let ideal = subview.sizeThatFits(.unspecified)
        guard let width = Self.squeezedWidth(ideal: ideal.width, line: lineWidth) else { return ideal }
        return subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
    }

    /// The width a child gets when it's wider than the line; nil when it fits.
    static func squeezedWidth(ideal: CGFloat, line: CGFloat) -> CGFloat? {
        guard line.isFinite, ideal > line else { return nil }
        return max(0, line)
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, in maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = fittedSize(of: subviews[index], in: maxWidth)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

#Preview {
    FlowLayout(spacing: 6) {
        ForEach(["diary", "mood", "gratitude", "reflection", "writing", "mindful", "habit", "memories"], id: \.self) {
            Pill(text: $0, style: .neutral)
        }
    }
    .frame(width: 220)
    .padding()
}
