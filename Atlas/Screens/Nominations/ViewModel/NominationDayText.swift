//
//  NominationDayText.swift
//  Atlas
//

import Foundation

/// "in 9 days", "tomorrow", "today", "4 days ago": how far a start date
/// is, in the nomination's lines.
enum NominationDayText {
    static func relative(_ days: Int) -> String {
        switch days {
        case 0: String(localized: "today", comment: "kind:description")
        case 1: String(localized: "tomorrow", comment: "kind:description")
        case 2...: String(localized: "in \(days) days", comment: "kind:description")
        case -1: String(localized: "yesterday", comment: "kind:description")
        default: String(localized: "\(-days) days ago", comment: "kind:description")
        }
    }

    /// "Dec 3 – Dec 31, 2026", "Dec 3, 2026 · no end date", or "No start
    /// date yet".
    static func dates(_ content: NominationContent) -> String {
        guard let start = content.publishStart else { return String(localized: "No start date yet", comment: "kind:empty-state") }
        let startText = start.formatted(date: .abbreviated, time: .omitted)
        guard let end = content.publishEnd else { return String(localized: "\(startText) · no end date", comment: "kind:description") }
        return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(date: .abbreviated, time: .omitted))"
    }
}
