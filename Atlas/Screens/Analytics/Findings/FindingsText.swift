//
//  FindingsText.swift
//  Atlas
//

import Foundation

/// What to Try's lines: its heading and the line on a finding whose change
/// waits in Review & Push.
enum FindingsText {
    /// "5 findings from the last 28 days".
    static func heading(count: Int, days: Int) -> String {
        count == 1
            ? String(localized: "1 finding from the last \(days) days", comment: "kind:section-title · What to Try")
            : String(localized: "\(count) findings from the last \(days) days", comment: "kind:section-title · What to Try")
    }

    static var subheading: String {
        String(
            localized: "From Atlas’s rules, Apple’s tests and your assistant. Each links to where you change it.",
            comment: "kind:description · What to Try"
        )
    }

    /// "2 changes in Pricing are waiting in Review & Push."; nil when
    /// nothing waits.
    static func waiting(count: Int, area: AnalyticsArea) -> String? {
        switch count {
        case ..<1: nil
        case 1: String(localized: "1 change in \(area.title) is waiting in Review & Push.", comment: "kind:status · a finding")
        default: String(localized: "\(count) changes in \(area.title) are waiting in Review & Push.", comment: "kind:status · a finding")
        }
    }
}
