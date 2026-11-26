//
//  AnalyticsEmptyDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Subscriptions and Stability with nothing to show yet (board 92, row 8),
/// as Apple's rules make them: `an-sub-none` (Lumen before its first
/// sale), `an-sub-trial` (Quiet Timer: one trial, nobody paid),
/// `an-sub-few` (Parcel Pal: 4 subscribers, too few for rates),
/// `an-crash-wait` (Lumen 1.4 used by 3 people who share analytics),
/// `an-crash-new` (Parcel Pal: 9 days, App Crashes sent empty) and
/// `an-crash-none` (Lumen: sessions, App Crashes sent empty).
enum AnalyticsEmptyDebugScenes {
    typealias AppIDs = DebugFixtures.AppID
    typealias Data = DebugAnalyticsData

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "an-sub-none": scene(store: lumenBeforeTheFirstSale(), tab: .subscriptions)
        case "an-sub-trial": scene(app: AppIDs.quiet, tab: .subscriptions)
        case "an-sub-few": scene(app: AppIDs.parcel, tab: .subscriptions)
        case "an-crash-wait": scene(store: lumen(reports: versionTooNew), tab: .stability)
        case "an-crash-new": scene(app: AppIDs.parcel, tab: .stability)
        case "an-crash-none": scene(store: lumen(reports: noCrashes), tab: .stability)
        default: nil
        }
    }

    /// The sample store with every app's sales but Lumen's: Sales and
    /// Trends is read, and has nothing of Lumen's yet.
    @MainActor
    private static func lumenBeforeTheFirstSale() -> AnalyticsStore {
        let store = Data.store()
        var sales = Data.sales
        sales.events.removeAll { $0.appID == AppIDs.lumen }
        sales.subscribers.removeAll { $0.appID == AppIDs.lumen }
        sales.active.removeAll { $0.appID == AppIDs.lumen }
        store.load(sales: sales, vendorNumber: "85012345")
        return store
    }

    /// The sample store with Lumen's newer reports replaced.
    @MainActor
    private static func lumen(reports: ReportsArchive) -> AnalyticsStore {
        let store = Data.store()
        store.load(
            appID: AppIDs.lumen, record: AnalyticsAppRecord(askedOn: Data.date(month: 5, day: 10), lastChecked: Data.today, announcedArrival: true),
            archive: Data.lumenArchive, reports: reports, gracePeriod: DebugReportsData.lumenGracePeriod
        )
        return store
    }

    /// 1.3 at about 2.1 crashes per 1,000 sessions; 1.4 went live on the
    /// newest day, used by 3 people who share analytics, with no crashes.
    private static var versionTooNew: ReportsArchive {
        var builder = DebugReportsData.Builder()
        for back in 0..<30 {
            let day = DebugReportsData.last.adding(-back)
            builder.add(.sessions, day: day, values: ["1.3", "iPhone", "App Store Search", "", "", "", "", "US"], counts: [2900, 2900 * 240, 960])
            builder.add(.crashes, day: day, values: ["1.3", "iPhone"], counts: [6, 0])
        }
        builder.add(.sessions, day: DebugReportsData.last, values: ["1.4", "iPhone", "App Store Search", "", "", "", "", "US"], counts: [9, 9 * 230, 3])
        return builder.archive(firstChecked: Data.date(month: 11, day: 1))
    }

    /// 1.4's sessions, and App Crashes sent with no rows.
    private static var noCrashes: ReportsArchive {
        var facts: [ReportFact] = []
        for back in 0..<30 {
            let values = ["1.4", "iPhone", "App Store Search", "", "", "", "", "US"]
            facts.append(ReportFact(day: DebugReportsData.last.adding(-back), values: values, counts: [300, 300 * 240, 110]))
        }
        var download = ReportsDownload()
        download.listed = [.crashes: 3, .sessions: 30]
        download.batches = [
            ReportBatch(instanceID: "debug-sessions", kind: .sessions, processing: DebugReportsData.last, facts: ReportFact.merged(facts)),
        ]
        var archive = ReportsArchive()
        archive.apply(download, now: Data.date(month: 11, day: 1))
        return archive
    }

    @MainActor
    private static func scene(app: StoreApp.ID = AppIDs.lumen, store: AnalyticsStore? = nil, tab: AnalyticsTab) -> AnyView {
        var services = WorkspaceServices.debug
        services.analytics = DebugAnalyticsServices()
        AnalyticsDebugLaunch.pending = AnalyticsDebugLaunch(tab: tab)
        return AnyView(DebugMainScene(
            services: services, selectedAppID: app, section: .analytics, pendingChanges: [], pushRecords: Data.pushRecords,
            analytics: store ?? Data.store()
        ))
    }
}
#endif
