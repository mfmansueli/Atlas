//
//  FunnelCalloutAction.swift
//  Atlas
//

import Foundation

/// Where a callout's button goes.
enum FunnelCalloutAction: Hashable, Sendable {
    /// After Changes, on the change pushed nearest the drop.
    case seeChange(MeasuredChange.ID)
    case breakDown(BreakdownDimension)

    var title: String {
        switch self {
        case .seeChange: String(localized: "See What Changed")
        case let .breakDown(dimension): String(localized: "Break Down by \(dimension.title)")
        }
    }
}
