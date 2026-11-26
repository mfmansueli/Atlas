//
//  BreakdownDimension+Picker.swift
//  Atlas
//

import Foundation

/// How Break It Down names its splits (board 92): the segmented control
/// shows Country, Language, Source, Device and Product Page; Referrer and
/// Campaign sit in its More menu.
extension BreakdownDimension {
    /// The splits in the segmented control, in its order.
    static let segmented: [BreakdownDimension] = [.territory, .language, .source, .device, .productPage]
    /// The rest, in the More menu beside it.
    static let more: [BreakdownDimension] = allCases.filter { !segmented.contains($0) }

    var isSegmented: Bool { Self.segmented.contains(self) }

    /// The segment's title: "Country" for territories.
    var segmentTitle: String {
        switch self {
        case .territory: String(localized: "Country", comment: "kind:segment · Break It Down by territory")
        default: title
        }
    }

    /// The table's first column.
    var columnTitle: String {
        switch self {
        case .territory: String(localized: "Country", comment: "kind:column · Break It Down")
        case .language: String(localized: "Store page language", comment: "kind:column · Break It Down")
        case .productPage: String(localized: "Product page", comment: "kind:column · Break It Down")
        case .source, .device, .referrer, .campaign: title
        }
    }

    /// The totals row under the header: "All territories".
    var totalsTitle: String {
        switch self {
        case .territory: String(localized: "All territories", comment: "kind:label · Break It Down totals row")
        case .language: String(localized: "All languages", comment: "kind:label · Break It Down totals row")
        case .source: String(localized: "All sources", comment: "kind:label · Break It Down totals row")
        case .device: String(localized: "All devices", comment: "kind:label · Break It Down totals row")
        case .productPage: String(localized: "All product pages", comment: "kind:label · Break It Down totals row")
        case .referrer: String(localized: "All referrers", comment: "kind:label · Break It Down totals row")
        case .campaign: String(localized: "All campaigns", comment: "kind:label · Break It Down totals row")
        }
    }
}
