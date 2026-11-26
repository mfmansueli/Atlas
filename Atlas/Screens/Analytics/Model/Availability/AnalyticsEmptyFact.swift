//
//  AnalyticsEmptyFact.swift
//  Atlas
//

import Foundation

/// One key/value line under an Analytics empty state: "Reports start" ·
/// "The day after the first sale", "Trials" · "4".
struct AnalyticsEmptyFact: Hashable, Sendable, Identifiable {
    let label: String
    let value: String

    var id: String { label }
}
