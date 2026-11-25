//
//  WatchDebugData.swift
//  Atlas
//

#if DEBUG
import Foundation

/// The sample findings and records behind `WatchDebugScenes`.
enum WatchDebugData {
    typealias AppIDs = DebugFixtures.AppID

    enum Scene: String {
        case watch
        case quiet = "watch-quiet"
        case cap = "watch-cap"
    }

    /// Nov 25, 2026 at `hour`, this Mac's time.
    static func date(hour: Int, day: Int = 25) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour)) ?? .now
    }

    /// On, Pro, Claude Code ready and every sample app's folder known.
    static let context = WatchContext(
        isOn: true, isPro: true, canStartClaudeCode: true, appsWithProjectFolder: [AppIDs.lumen, AppIDs.habitat, AppIDs.tempo]
    )

    @MainActor
    static func center(for scene: Scene) -> WatchCenter {
        let center = WatchCenter()
        switch scene {
        case .watch:
            center.now = { date(hour: 10) }
        case .quiet:
            center.now = { date(hour: 23) }
        case .cap:
            center.now = { date(hour: 15) }
            var habitat = WatchArchive()
            habitat.updateStats(for: .crashesWorse) {
                $0.isPaused = true
                $0.asksKeepSuggesting = true
                $0.dismissalsInARow = 3
            }
            center.load(habitat, for: AppIDs.habitat)
            for (index, appID) in [AppIDs.fieldnote, AppIDs.parcel, AppIDs.quiet].enumerated() {
                var archive = WatchArchive()
                archive.append(WatchHistoryEntry(
                    id: UUID(), appID: appID, appName: appID, startedAt: date(hour: 9 + index), endedAt: date(hour: 9 + index), signals: [],
                    result: .finished, isSettled: true
                ))
                center.load(archive, for: appID)
            }
        }
        return center
    }

    static func inputs(now: Date) -> [WatchInputs] {
        [lumen(now: now), habitat(now: now), tempo(now: now)]
    }

    /// What's New missing in three languages with 14 commits since v1.4, an
    /// event showing in 3 days without German, and reviews since 1.5 low.
    static func lumen(now: Date) -> WatchInputs {
        var inputs = WatchInputs(appID: AppIDs.lumen, appName: "Lumen Journal", now: now)
        inputs.version = WatchInputs.Version(id: "lumen-1.5", versionString: "1.5", phase: .prepare)
        inputs.whatsNew = WatchInputs.WhatsNew(languages: 8, missing: ["de-DE", "ja", "pt-BR"], suggested: 1)
        inputs.commits = WatchInputs.Commits(tag: "v1.4", count: 14)
        inputs.events = [WatchEventFacts(
            id: "6740000001", name: "Winter Reflection", isEditable: true, deadline: now.addingTimeInterval(3 * 86400),
            missingForReview: ["deepLink"], missingLanguages: ["de-DE"]
        )]
        inputs.reviewedVersion = "1.4"
        inputs.reviews = (0..<8).map { index in
            AppReview(
                id: "watch-r\(index)", territory: "US", rating: index < 4 ? 1 : 4, title: "Sync", body: "Entries vanish after the update.",
                nickname: "reader\(index)", date: now.addingTimeInterval(-Double(index) * 86400), version: "1.4", languageCode: "en"
            )
        }
        return inputs
    }

    /// 1.4 crashes 3.2× as often as 1.3.
    static func habitat(now: Date) -> WatchInputs {
        var inputs = WatchInputs(appID: AppIDs.habitat, appName: "Habitat — Plant Care", now: now)
        inputs.stability = StabilityReport(
            period: AnalyticsPeriod(ending: AnalyticsDay(now), length: 7),
            latest: .init(version: "1.4", crashes: 96, sessions: 30000, devices: 1200),
            previous: .init(version: "1.3", crashes: 30, sessions: 30000, devices: 1200),
            comparison: .higher(.sure), devices: [], days: []
        )
        return inputs
    }

    /// 2.1 in Prepare for Submission without the encryption answer or the
    /// age rating: Atlas's own lines, never sent.
    static func tempo(now: Date) -> WatchInputs {
        var inputs = WatchInputs(appID: AppIDs.tempo, appName: "Tempo Metronome", now: now)
        inputs.version = WatchInputs.Version(id: "tempo-2.1", versionString: "2.1", phase: .prepare)
        inputs.blockers = [.exportCompliance, .ageRating]
        return inputs
    }
}
#endif
