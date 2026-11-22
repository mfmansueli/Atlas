//
//  ReportMeasure.swift
//  Atlas
//

import Foundation

/// A number Atlas adds up from one of Apple's newer analytics reports.
enum ReportMeasure: String, Hashable, Sendable, Codable, CaseIterable {
    case counts
    case uniqueDevices
    case crashes
    case sessions
    /// Seconds, all sessions together.
    case duration

    var columnNames: [String] {
        switch self {
        case .counts: ["Counts", "Count"]
        case .uniqueDevices: ["Unique Devices"]
        case .crashes: ["Crashes"]
        case .sessions: ["Sessions"]
        case .duration: ["Total Session Duration"]
        }
    }
}
