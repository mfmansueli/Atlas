//
//  EmptyStateSize.swift
//  Atlas
//

import CoreGraphics

/// How big an empty state is (README-DS §14, board 74): a whole page's,
/// or the smaller one inside a list, a table or a sheet, which sits where
/// the rows would be (a filter with no results, a search, Review & Push
/// with nothing to push).
enum EmptyStateSize: Sendable {
    case page
    case inline

    /// The section's symbol: 44 pt on a page, 32 pt inside a list.
    var symbolSize: CGFloat {
        switch self {
        case .page: Metrics.emptyStateSymbol
        case .inline: Metrics.emptyStateInlineSymbol
        }
    }

    /// The title: Title 2 (17 pt) on a page, Title 3 (15 pt) inside a list.
    var titleStyle: AtlasTextStyle {
        switch self {
        case .page: .title2
        case .inline: .title3
        }
    }

    /// What lifts a page's empty state a little above the middle; an
    /// inline one sits where the rows would be, with its own room above
    /// and below.
    var bottomInset: CGFloat {
        switch self {
        case .page: Metrics.emptyStateLift
        case .inline: Spacing.xxLarge
        }
    }

    var topInset: CGFloat {
        switch self {
        case .page: 0
        case .inline: Spacing.xxLarge
        }
    }
}
