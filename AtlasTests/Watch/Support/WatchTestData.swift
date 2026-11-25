//
//  WatchTestData.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Findings, inputs and dates for the Look for Improvements tests: Lumen
/// Journal, Nov 16, 2026 at noon in UTC.
enum WatchTestData {
    static let lumen: StoreApp.ID = "6450000001"
    static let tempo: StoreApp.ID = "6450000003"
    static let now = Date(timeIntervalSince1970: 1_794_830_400)
    static let day: TimeInterval = 86400

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }

    /// `now`'s day at `hour`:`minute` UTC, `days` later.
    static func date(hour: Int, minute: Int = 0, days: Int = 0) -> Date {
        let start = calendar.startOfDay(for: now)
        return start.addingTimeInterval(Double(days) * day + Double(hour) * 3600 + Double(minute) * 60)
    }

    static func signal(
        _ kind: WatchSignalKind = .whatsNewMissing, app: StoreApp.ID = lumen, subject: String = "1.5", value: Double = 3,
        numbers: [String: Double]? = nil, deadline: Date? = nil
    ) -> WatchSignal {
        WatchSignal(
            kind: kind, appID: app, subject: subject, value: value, numbers: numbers ?? ["n": value], summary: "\(kind.rawValue) \(subject)",
            deadline: deadline
        )
    }

    /// On, Pro, Claude Code ready, Lumen's and Tempo's folders known.
    static let context = WatchContext(isOn: true, isPro: true, canStartClaudeCode: true, appsWithProjectFolder: [lumen, tempo])

    /// 1.5 in Prepare for Submission, What's New missing in 3 of 8 languages,
    /// 14 commits since v1.4.
    static func whatsNewInputs(app: StoreApp.ID = lumen, at date: Date = now) -> WatchInputs {
        var inputs = WatchInputs(appID: app, appName: app == lumen ? "Lumen Journal" : "Tempo Metronome", now: date)
        inputs.version = WatchInputs.Version(id: "v15", versionString: "1.5", phase: .prepare)
        inputs.whatsNew = WatchInputs.WhatsNew(languages: 8, missing: ["de-DE", "ja", "pt-BR"], suggested: 1)
        inputs.commits = WatchInputs.Commits(tag: "v1.4", count: 14)
        return inputs
    }

    static func event(
        id: String = "e1", editable: Bool = true, in days: Double = 3, missing: [String] = ["deepLink"], languages: [String] = ["de-DE"]
    ) -> WatchEventFacts {
        WatchEventFacts(
            id: id, name: "Winter Reflection", isEditable: editable, deadline: now.addingTimeInterval(days * day), missingForReview: missing,
            missingLanguages: languages
        )
    }

    static func stability(latest: Int, previous: Int, comparison: ComparisonOutcome) -> StabilityReport {
        StabilityReport(
            period: AnalyticsPeriod(ending: AnalyticsDay(now), length: 7),
            latest: .init(version: "1.4", crashes: latest, sessions: 30000, devices: 1200),
            previous: .init(version: "1.3", crashes: previous, sessions: 30000, devices: 1200),
            comparison: comparison, devices: [], days: []
        )
    }

    static func review(_ index: Int, rating: Int, version: String = "1.4", daysAgo: Double = 1) -> AppReview {
        AppReview(
            id: "r\(version)-\(index)", territory: "US", rating: rating, title: "Title", body: "Body", nickname: "n\(index)",
            date: now.addingTimeInterval(-daysAgo * day), version: version, languageCode: "en"
        )
    }
}
