//
//  Metrics+EmptyState.swift
//  Atlas
//

import CoreGraphics

/// The empty states' sizes (README-DS §14, board 74; design-tokens.json →
/// emptyState): the prototype's `.cuvw`.
extension Metrics {
    /// The section's symbol on a page, and inside a list, a table or a sheet.
    static let emptyStateSymbol: CGFloat = 44
    static let emptyStateInlineSymbol: CGFloat = 32
    /// How wide the sentences and the small line run.
    static let emptyStateTextWidth: CGFloat = 440
    /// What lifts a page's empty state a little above the middle.
    static let emptyStateLift: CGFloat = 48
}
