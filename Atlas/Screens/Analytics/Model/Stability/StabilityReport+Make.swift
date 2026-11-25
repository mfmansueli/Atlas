//
//  StabilityReport+Make.swift
//  Atlas
//

import Foundation

extension StabilityReport {
    /// Days compared, at most.
    static let comparedDays = 14

    /// nil without crash or session rows for a version. Crashes without
    /// sessions still make a report: the counts, with no rate (README-An2).
    static func make(_ reports: ReportsArchive, now: AnalyticsDay) -> StabilityReport? {
        let crashes = reports.records(.crashes)
        let sessions = reports.records(.sessions)
        // The days and versions come from sessions; without them, from crashes.
        let base = sessions.isEmpty ? crashes : sessions
        guard !base.isEmpty else { return nil }
        let versions = Set(base.map { $0[.appVersion] }).filter { !$0.isEmpty }.sorted(by: AppVersionOrder.isBefore)
        guard let newest = versions.last else { return nil }
        let older = versions.dropLast().last
        let through = min(now.adding(-AppleReportKind.crashes.completeAfterDays), base.map(\.day).max() ?? now)
        let newestDays = Set(base.filter { $0[.appVersion] == newest }.map(\.day))
        let olderDays = older.map { version in Set(base.filter { $0[.appVersion] == version }.map(\.day)) } ?? newestDays
        let shared = newestDays.intersection(olderDays).filter { $0 <= through }.sorted().suffix(comparedDays)
        let compared = shared.isEmpty ? Array(newestDays.filter { $0 <= through }.sorted().suffix(comparedDays)) : Array(shared)
        guard let first = compared.first, let last = compared.last else { return nil }
        let period = AnalyticsPeriod(first: first, last: last)
        let days = Set(compared)
        let crashesIn = crashes.filter { days.contains($0.day) }
        let sessionsIn = sessions.filter { days.contains($0.day) }
        let latest = numbers(newest, crashes: crashesIn, sessions: sessionsIn)
        let previous = older.map { numbers($0, crashes: crashesIn, sessions: sessionsIn) }
        return StabilityReport(
            period: period,
            latest: latest,
            previous: previous,
            comparison: previous.map { comparison(latest, against: $0) } ?? .tooFew,
            devices: deviceRows(newest: newest, older: older, crashes: crashesIn, sessions: sessionsIn, base: sessions.isEmpty ? crashesIn : sessionsIn),
            days: compared.map { day in
                let dayCrashes = crashesIn.filter { $0.day == day }
                let daySessions = sessionsIn.filter { $0.day == day }
                return Day(
                    day: day,
                    latest: numbers(newest, crashes: dayCrashes, sessions: daySessions).perThousand,
                    previous: older.flatMap { numbers($0, crashes: dayCrashes, sessions: daySessions).perThousand }
                )
            }
        )
    }

    /// Crashes per session of one version against another's: the same test
    /// as two rates, with the minimums of a single rate.
    static func comparison(_ latest: VersionNumbers, against previous: VersionNumbers) -> ComparisonOutcome {
        AnalyticsStatistics.compare(
            count: min(latest.crashes, latest.sessions), total: latest.sessions,
            previousCount: min(previous.crashes, previous.sessions), previousTotal: previous.sessions,
            minimumTotal: AnalyticsStatistics.minimumTotal, minimumCount: AnalyticsStatistics.minimumCount
        ).outcome
    }

    private static func numbers(_ version: String, crashes: [ReportRecord], sessions: [ReportRecord]) -> VersionNumbers {
        let versionCrashes = crashes.filter { $0[.appVersion] == version }
        let versionSessions = sessions.filter { $0[.appVersion] == version }
        return VersionNumbers(
            version: version,
            crashes: versionCrashes.total(.crashes),
            sessions: versionSessions.total(.sessions),
            devices: versionSessions.total(.uniqueDevices)
        )
    }

    /// The devices in `base` (sessions, else crashes) the newest version
    /// ran or crashed on, the busiest first.
    private static func deviceRows(
        newest: String, older: String?, crashes: [ReportRecord], sessions: [ReportRecord], base: [ReportRecord]
    ) -> [DeviceRow] {
        let devices = Set(base.map { $0[.device] }).filter { !$0.isEmpty }
        return devices.compactMap { device -> DeviceRow? in
            let deviceCrashes = crashes.filter { $0[.device] == device }
            let deviceSessions = sessions.filter { $0[.device] == device }
            let latest = numbers(newest, crashes: deviceCrashes, sessions: deviceSessions)
            guard latest.sessions > 0 || (sessions.isEmpty && latest.crashes > 0) else { return nil }
            return DeviceRow(device: device, latest: latest, previous: older.map { numbers($0, crashes: deviceCrashes, sessions: deviceSessions) })
        }
        .sorted { ($0.latest.sessions, $0.latest.crashes, $1.device) > ($1.latest.sessions, $1.latest.crashes, $0.device) }
    }
}
