//
//  CrashesSoFar.swift
//  Atlas
//

import Foundation

/// What Apple's App Crashes, App Sessions and Installations reports say so
/// far, for Stability's card and its empty states. Apple's rules behind it:
///
/// - Crashes come only from people who share analytics with developers,
///   and a version's crashes show only once at least 5 of them
///   (`AnalyticsTabAvailability.minimumPeople`) had one.
/// - So a version used by fewer than 5 of them is too new to tell, even
///   when it already has installs or a few sessions.
/// - An App Crashes report sent without rows means fewer than 5 people
///   had a crash: "No crashes reported", or "Not enough people yet" for an
///   app with less than a full period of data.
struct CrashesSoFar: Hashable, Sendable {
    /// Apple has sent App Crashes, with rows or empty.
    var isReported = false
    /// Any version has a crash row.
    var hasCrashRows = false
    /// The newest version in any of the three reports.
    var newest: String?
    var newestCrashes = 0
    var newestSessions = 0
    /// People on the newest version who share analytics (unique devices
    /// in App Sessions, the last `StabilityReport.comparedDays` days).
    var newestDevices = 0
    /// The version before the newest, and its crashes per 1,000 sessions
    /// over its last compared days; nil without sessions.
    var previous: String?
    var previousRate: Double?
    /// Sessions over the last 28 days of App Sessions.
    var recentSessions = 0
    /// Less than a full period of store-page data.
    var isNewApp = false
    /// Downloads so far, from the store-page reports.
    var downloads = 0
    /// The first day of data.
    var firstDay: AnalyticsDay?

    /// Apple's rules, in order: a newest version too few people use yet,
    /// then no crash rows at all (an app too new, or none to report).
    var availability: AnalyticsTabAvailability {
        if let newest, let previous, newestCrashes == 0, newestDevices < AnalyticsTabAvailability.minimumPeople {
            return .versionTooNew(version: newest, previous: previous, previousRate: previousRate)
        }
        guard isReported, !hasCrashRows else { return .available }
        return isNewApp ? .notEnoughPeople : .noCrashes
    }

    static func make(_ dataset: AnalyticsDataset) -> CrashesSoFar {
        let reports = dataset.reports
        let crashes = reports.records(.crashes)
        let sessions = reports.records(.sessions)
        let installs = reports.records(.installs)
        let versions = Set((crashes + sessions + installs).map { $0[.appVersion] }).filter { !$0.isEmpty }.sorted(by: AppVersionOrder.isBefore)
        let newest = versions.last
        let previous = versions.dropLast().last
        let newestSessions = recent(sessions.filter { $0[.appVersion] == newest }, days: StabilityReport.comparedDays)
        return CrashesSoFar(
            isReported: reports.progress(.crashes).state != .asked || !crashes.isEmpty,
            hasCrashRows: crashes.contains { $0.count(.crashes) > 0 },
            newest: newest,
            newestCrashes: crashes.filter { $0[.appVersion] == newest }.total(.crashes),
            newestSessions: newestSessions.total(.sessions),
            newestDevices: newestSessions.total(.uniqueDevices),
            previous: previous,
            previousRate: previous.flatMap { rate($0, crashes: crashes, sessions: sessions) },
            recentSessions: recent(sessions, days: 28).total(.sessions),
            isNewApp: (1..<AnalyticsAvailability.newAppDays).contains(dataset.dayCount),
            downloads: dataset.engagement.reduce(0) { $0 + $1.downloads },
            firstDay: dataset.firstDay
        )
    }

    /// `records` on their newest `days` days.
    private static func recent(_ records: [ReportRecord], days: Int) -> [ReportRecord] {
        guard let last = records.map(\.day).max() else { return [] }
        return records.within(AnalyticsPeriod(ending: last, length: days))
    }

    /// One version's crashes per 1,000 sessions over its newest compared
    /// days; nil without sessions.
    private static func rate(_ version: String, crashes: [ReportRecord], sessions: [ReportRecord]) -> Double? {
        let own = recent(sessions.filter { $0[.appVersion] == version }, days: StabilityReport.comparedDays)
        guard let first = own.map(\.day).min(), let last = own.map(\.day).max() else { return nil }
        let period = AnalyticsPeriod(first: first, last: last)
        let count = own.total(.sessions)
        guard count > 0 else { return nil }
        let crashed = crashes.filter { $0[.appVersion] == version }.within(period).total(.crashes)
        return Double(crashed) * 1000 / Double(count)
    }
}
