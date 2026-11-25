//
//  AnalyticsDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The Analytics section's DEBUG scenes (`-AtlasDebugScene <id>`),
/// one per state on the design's Analytics boards (29–37). "Today" is Nov
/// 11, 2026.
///
/// - Setup: `an-off`, `an-waiting` (Habitat, asked Nov 10), `an-norole`,
///   `an-loading`.
/// - What's missing: `an-novendor`, `an-nosales`, `an-part-eng` (sales not
///   yet), `an-part-sales` (store-page reports not yet), `an-stale`.
/// - Funnel: `an-funnel`, `an-funnel-7`, `an-funnel-dl` (90 days, trials
///   charted), `an-quiet`, `an-nosub`, `an-new`.
/// - Break It Down: `an-bd`, `an-bd-de`, `an-bd-br`, `an-bd-lang`,
///   `an-bd-src`, `an-bd-dev`, `an-bd-ppo`.
/// - What to Try: `an-find`, `an-find-wait`, `an-find-done`, `an-find-dis`,
///   `an-find-none`.
/// - After Changes: `an-chg`, `an-chg-wait`, `an-chg-few`, `an-chg-price`.
/// - `an-sub`, settings: `an-set`, `an-set-vendor`, and the overview's
///   card with the gray count on the section picker: `an-overview`.
/// - Apple's newer reports (boards 59–62): `an-sub-ret`, `an-sub-ret-few`
///   (Quiet Timer, 3 of 14), `an-sub-ret-none` (Parcel Pal, sent empty),
///   `an-sub-offers`, `an-sub-billing`, `an-stab`, `an-stab-counts`
///   (crashes without sessions: counts, no rate), `an-bd-page-sub`,
///   `an-bd-camp`, `an-reports`, `an-preparing` (Tempo), and elsewhere
///   `an-reviews-crash`, `an-pages-sub`.
/// - The redesign's ids: `an-crash` (Stability, its banner with Open
///   Version), `an-sub2` (Subscriptions), `an-set-stop` (settings with
///   Lumen's stop confirmation open), `an-bd-dev-ipad` (iPad selected: its
///   set covers 4 of 10 languages), `an-bd-src-browse`, `an-jump-br`
///   (Pricing's Annual page on Brazil under "From Analytics"), `an-jump`
///   (Store Page in German under it), and with the sidebar hidden
///   `an-funnel-s` and `an-bd-s`.
enum AnalyticsDebugScenes {
    typealias AppIDs = DebugFixtures.AppID
    typealias Data = DebugAnalyticsData

    @MainActor
    static func view(for id: String) -> AnyView? {
        setupScene(id) ?? funnelScene(id) ?? breakdownScene(id) ?? findingsScene(id) ?? otherScene(id) ?? redesignScene(id)
    }

    /// The redesign's Analytics scenes not named above.
    @MainActor
    private static func redesignScene(_ id: String) -> AnyView? {
        switch id {
        case "an-crash": return scene(launch: AnalyticsDebugLaunch(tab: .stability))
        case "an-sub2": return scene(launch: AnalyticsDebugLaunch(tab: .subscriptions))
        case "an-set-stop": return scene(launch: AnalyticsDebugLaunch(opensSettings: true, settingsFocus: .stopReports(AppIDs.lumen)))
        case "an-bd-dev-ipad": return scene(launch: AnalyticsDebugLaunch(tab: .breakdown, dimension: .device, selectedRow: "iPad"))
        case "an-bd-src-browse":
            return scene(launch: AnalyticsDebugLaunch(tab: .breakdown, dimension: .source, selectedRow: BreakdownInspectorFacts.browse))
        case "an-jump-br":
            let text = "Brazil’s trials convert at a third of Lumen’s average. Annual costs 2.4× the purchasing-power price there."
            return scene(launch: AnalyticsDebugLaunch(tab: .findings, follow: .pricing(territory: "BR"), followText: text))
        case "an-jump":
            let text = "Germany downloads half as much as the U.S. on a machine-translated page."
            return scene(launch: AnalyticsDebugLaunch(tab: .findings, follow: .storePage(locale: "de-DE"), followText: text))
        case "an-funnel-s":
            NavigationDebugLaunch.hidesSidebar = true
            return scene()
        case "an-bd-s":
            NavigationDebugLaunch.hidesSidebar = true
            return scene(launch: AnalyticsDebugLaunch(tab: .breakdown, selectedRow: "DE"))
        default: return nil
        }
    }

    @MainActor
    private static func setupScene(_ id: String) -> AnyView? {
        switch id {
        case "an-off":
            // Nothing of Lumen's on this Mac yet, sales included: asking leads to waiting, as it does for real.
            let store = Data.store(hasSales: false)
            store.load(appID: AppIDs.lumen, record: AnalyticsAppRecord())
            return scene(store: store)
        case "an-waiting":
            return scene(app: AppIDs.habitat)
        case "an-norole":
            let store = Data.store()
            store.load(appID: AppIDs.lumen, record: AnalyticsAppRecord(keyCannotAsk: true))
            return scene(store: store, services: DebugAnalyticsServices(keyCannotAsk: true))
        case "an-loading":
            let store = Data.store()
            store.load(appID: AppIDs.habitat, record: AnalyticsAppRecord(askedOn: Data.date(month: 11, day: 9)))
            return scene(app: AppIDs.habitat, store: store, services: DebugAnalyticsServices(neverFinishes: true))
        case "an-novendor":
            return scene(store: Data.store(vendorNumber: "", hasSales: false))
        case "an-nosales":
            return scene(store: Data.store(keyCannotReadSales: true, hasSales: false))
        case "an-part-eng":
            return scene(store: Data.store(hasSales: false))
        case "an-part-sales":
            let store = Data.store()
            store.load(appID: AppIDs.lumen, record: AnalyticsAppRecord(askedOn: Data.date(month: 11, day: 10), lastChecked: Data.today))
            return scene(store: store)
        case "an-stale":
            let store = Data.store()
            let later = Data.date(month: 11, day: 14, hour: 8)
            store.now = { later }
            store.load(
                appID: AppIDs.lumen, record: AnalyticsAppRecord(askedOn: Data.date(month: 5, day: 10), lastChecked: later, announcedArrival: true),
                archive: Data.lumenArchive
            )
            return scene(store: store)
        default:
            return nil
        }
    }

    @MainActor
    private static func funnelScene(_ id: String) -> AnyView? {
        switch id {
        case "an-funnel": scene()
        case "an-funnel-7": scene(launch: AnalyticsDebugLaunch(days: 7))
        case "an-funnel-dl": scene(launch: AnalyticsDebugLaunch(days: 90, stage: .trials))
        case "an-quiet": scene(app: AppIDs.quiet)
        case "an-nosub": scene(app: AppIDs.tempo)
        case "an-new": scene(app: AppIDs.parcel)
        default: nil
        }
    }

    @MainActor
    private static func breakdownScene(_ id: String) -> AnyView? {
        switch id {
        case "an-bd": scene(launch: AnalyticsDebugLaunch(tab: .breakdown))
        case "an-bd-de": scene(launch: AnalyticsDebugLaunch(tab: .breakdown, selectedRow: "DE"))
        case "an-bd-br": scene(launch: AnalyticsDebugLaunch(tab: .breakdown, selectedRow: "BR", sort: .viewRate))
        case "an-bd-lang": scene(launch: AnalyticsDebugLaunch(tab: .breakdown, dimension: .language))
        case "an-bd-src": scene(launch: AnalyticsDebugLaunch(tab: .breakdown, dimension: .source, selectedRow: "App Store Search"))
        case "an-bd-dev": scene(launch: AnalyticsDebugLaunch(tab: .breakdown, dimension: .device))
        case "an-bd-ppo": scene(launch: AnalyticsDebugLaunch(tab: .breakdown, dimension: .productPage))
        default: nil
        }
    }

    @MainActor
    private static func findingsScene(_ id: String) -> AnyView? {
        switch id {
        case "an-find":
            return scene(launch: AnalyticsDebugLaunch(tab: .findings))
        case "an-find-wait":
            let waiting = PendingChange(
                id: "pricing.debug.annual.BR", appID: AppIDs.lumen, section: .subscriptionPricing, group: "Subscription Pricing · Annual",
                title: "Brazil", flagRegion: "BR", oldValue: "R$ 249,90", newValue: "R$ 104,90", requests: []
            )
            return scene(launch: AnalyticsDebugLaunch(tab: .findings), pendingChanges: [waiting])
        case "an-find-done":
            let store = Data.store()
            store.updateFindings({ $0.actedOn["territory.downloads.DE"] = Data.date(month: 9, day: 30) }, for: AppIDs.lumen)
            return scene(store: store, launch: AnalyticsDebugLaunch(tab: .findings, findingsFilter: .actedOn))
        case "an-find-dis":
            let store = Data.store()
            let finding = AnalyticsFinding(
                id: "territory.views.KR", source: .builtIn, title: "South Korea views the page less often than average (4.4% vs 5.4%).", why: "",
                sureness: "Rough", surenessDetail: "", action: .storePage(locale: "ko")
            )
            store.updateFindings({ $0.dismissed = [DismissedFinding(finding: finding, date: Data.date(month: 11, day: 2))] }, for: AppIDs.lumen)
            return scene(store: store, launch: AnalyticsDebugLaunch(tab: .findings, findingsFilter: .dismissed))
        case "an-find-none":
            return scene(app: AppIDs.parcel, launch: AnalyticsDebugLaunch(tab: .findings))
        default:
            return nil
        }
    }

    @MainActor
    private static func otherScene(_ id: String) -> AnyView? {
        switch id {
        case "an-chg": scene(launch: AnalyticsDebugLaunch(tab: .changes, change: .searchText))
        case "an-chg-wait": scene(launch: AnalyticsDebugLaunch(tab: .changes, change: .screenshots))
        case "an-chg-few": scene(launch: AnalyticsDebugLaunch(tab: .changes, change: .searchText, picksLastChange: true))
        case "an-chg-price": scene(launch: AnalyticsDebugLaunch(tab: .changes, change: .prices))
        case "an-sub": scene(launch: AnalyticsDebugLaunch(tab: .subscriptions))
        case "an-sub-ret": scene(launch: AnalyticsDebugLaunch(tab: .subscriptions, pane: .retention))
        case "an-sub-ret-few": scene(app: AppIDs.quiet, launch: AnalyticsDebugLaunch(tab: .subscriptions, pane: .retention))
        case "an-sub-ret-none": scene(app: AppIDs.parcel, launch: AnalyticsDebugLaunch(tab: .subscriptions, pane: .retention))
        case "an-sub-offers": scene(launch: AnalyticsDebugLaunch(tab: .subscriptions, pane: .offers))
        case "an-sub-billing": scene(launch: AnalyticsDebugLaunch(tab: .subscriptions, pane: .billing))
        case "an-stab": scene(launch: AnalyticsDebugLaunch(tab: .stability))
        case "an-stab-counts": scene(store: crashesOnlyStore(), launch: AnalyticsDebugLaunch(tab: .stability))
        case "an-bd-page-sub": scene(launch: AnalyticsDebugLaunch(tab: .breakdown, dimension: .productPage, columnGroup: .afterDownload))
        case "an-bd-camp": scene(launch: AnalyticsDebugLaunch(tab: .breakdown, dimension: .campaign, columnGroup: .afterDownload))
        case "an-reports": scene(launch: AnalyticsDebugLaunch(opensReports: true))
        case "an-preparing": scene(app: AppIDs.tempo)
        case "an-reviews-crash": scene(section: .reviews)
        case "an-pages-sub": scene(section: .productPages)
        case "an-overview": scene(section: .overview)
        case "an-set": scene(launch: AnalyticsDebugLaunch(opensSettings: true))
        case "an-set-vendor":
            scene(store: Data.store(vendorNumber: "", hasSales: false), launch: AnalyticsDebugLaunch(opensSettings: true, settingsFocus: .vendorNumber))
        default: nil
        }
    }

    /// The sample store with Lumen's crashes and no sessions.
    @MainActor
    private static func crashesOnlyStore() -> AnalyticsStore {
        let store = Data.store()
        store.load(
            appID: AppIDs.lumen, record: AnalyticsAppRecord(askedOn: Data.date(month: 5, day: 10), lastChecked: Data.today, announcedArrival: true),
            archive: Data.lumenArchive, reports: DebugReportsData.lumenCrashesOnly, gracePeriod: DebugReportsData.lumenGracePeriod
        )
        return store
    }

    @MainActor
    private static func scene(
        app: StoreApp.ID = AppIDs.lumen,
        store: AnalyticsStore? = nil,
        services analytics: DebugAnalyticsServices = DebugAnalyticsServices(),
        launch: AnalyticsDebugLaunch = AnalyticsDebugLaunch(),
        pendingChanges: [PendingChange] = [],
        section: AppWorkspaceSection = .analytics
    ) -> AnyView {
        var services = WorkspaceServices.debug
        services.analytics = analytics
        AnalyticsDebugLaunch.pending = launch
        return AnyView(DebugMainScene(
            services: services, selectedAppID: app, section: section, pendingChanges: pendingChanges, pushRecords: Data.pushRecords,
            analytics: store ?? Data.store()
        ))
    }
}
#endif
