//
//  StabilityReport.swift
//  Atlas
//

import Foundation

/// Crashes of the newest version against the one before, on the same
/// days, from Apple's App Crashes and App Sessions reports. Both count only
/// people who share analytics with developers: a sample.
struct StabilityReport: Hashable, Sendable {
    /// One version's crashes and sessions on the compared days.
    struct VersionNumbers: Hashable, Sendable {
        var version: String
        var crashes: Int
        var sessions: Int
        var devices: Int

        /// Crashes per 1,000 sessions; nil without sessions.
        var perThousand: Double? {
            sessions > 0 ? Double(crashes) * 1000 / Double(sessions) : nil
        }
    }

    struct DeviceRow: Hashable, Sendable, Identifiable {
        var device: String
        var latest: VersionNumbers
        var previous: VersionNumbers?

        var id: String { device }

        /// How many times as often the newest version crashes here.
        var times: Double? {
            guard let new = latest.perThousand, let old = previous?.perThousand, old > 0 else { return nil }
            return new / old
        }
    }

    struct Day: Hashable, Sendable, Identifiable {
        var day: AnalyticsDay
        var latest: Double?
        var previous: Double?

        var id: Int { day.number }
    }

    /// Days both versions had sessions (complete days only).
    var period: AnalyticsPeriod
    var latest: VersionNumbers
    var previous: VersionNumbers?
    /// Crash rate of the newest version against the one before.
    var comparison: ComparisonOutcome
    var devices: [DeviceRow]
    var days: [Day]

    /// How many times as often the newest version crashes.
    var times: Double? {
        guard let new = latest.perThousand, let old = previous?.perThousand, old > 0 else { return nil }
        return new / old
    }

    /// The device where the newest version crashes most, against the one before.
    var mostAffected: DeviceRow? {
        devices.filter { ($0.times ?? 0) > 1 }.max { ($0.times ?? 0) < ($1.times ?? 0) }
    }

    /// Atlas warns only when the newest version is worse and it's at
    /// least fairly sure.
    var isWorse: Bool { comparison.isHigher }

    /// "Version 1.4 crashes 3.2× as often as 1.3 on the same days."
    var headline: String? {
        guard isWorse, let previous, let times else { return nil }
        return String(localized: "Version \(latest.version) crashes \(AnalyticsText.times(times)) as often as \(previous.version) on the same days.")
    }
}
