//
//  ReleaseEventsDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The Submit sheet's In-App Event states (`-AtlasDebugScene <id>`), with
/// Lumen Journal 1.4 and its Mood Calendar event ticked, What's New and
/// encryption answered:
///
/// - `rel-sheet-ev-missing`: the event has no deep link: blocked, with
///   Fix…, and the footer says to fix or untick it.
/// - `rel-sheet-ev-unclaimed`: its lumen:// link isn't in Lumen's
///   project: blocked, with Make It Work….
/// - `rel-sheet-ev-unchecked`: the project declares lumen://, nobody
///   checked the event: a calm note with Check in the Code.
/// - `rel-sheet-ev-older`: Claude Code found it opens in build 212, and
///   211 is chosen: a warning with Use Build 212.
/// - `rel-sheet-ev-fails`: Claude Code found it doesn't open yet: a
///   warning, Submit still on.
/// - `rel-sheet-ev-dates`: its card was set to show from Nov 16 at 00:00
///   GMT, which has passed (the clock is at 12:00): blocked, with Fix… on
///   its dates.
/// - `rel-sheet-ev-soon`: it starts in 20 hours: a warning about App
///   Review's time, Submit still on.
enum ReleaseEventsDebugScenes {
    typealias AppIDs = DebugFixtures.AppID
    typealias Links = InAppEventsDeepLinkDebugScenes

    static let ids = [
        "rel-sheet-ev-missing", "rel-sheet-ev-unclaimed", "rel-sheet-ev-unchecked", "rel-sheet-ev-older", "rel-sheet-ev-fails", "rel-sheet-ev-dates",
        "rel-sheet-ev-soon",
    ]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "rel-sheet-ev-missing":
            var mood = DebugInAppEventsData.mood
            mood.deepLink = nil
            return scene(claims: Links.claims(declaresScheme: true), events: [DebugInAppEventsData.winter, mood, DebugInAppEventsData.gratitude])
        case "rel-sheet-ev-unclaimed":
            return scene(claims: Links.claims(declaresScheme: false))
        case "rel-sheet-ev-unchecked":
            return scene(claims: Links.claims(declaresScheme: true))
        case "rel-sheet-ev-older":
            return scene(claims: Links.claims(declaresScheme: true), report: Links.report(opens: true), buildID: "build-211")
        case "rel-sheet-ev-fails":
            return scene(claims: Links.claims(declaresScheme: true), report: Links.report(opens: false))
        case "rel-sheet-ev-dates":
            var mood = DebugInAppEventsData.mood
            mood.schedules[0].publishStart = DebugInAppEventsData.date(month: 11, day: 16, hour: 0)
            return scene(claims: Links.claims(declaresScheme: true), events: [DebugInAppEventsData.winter, mood, DebugInAppEventsData.gratitude])
        case "rel-sheet-ev-soon":
            let events = [DebugInAppEventsData.winter, InAppEventsDatesDebugScenes.soonMood, DebugInAppEventsData.gratitude]
            return scene(claims: Links.claims(declaresScheme: true), events: events)
        default:
            return nil
        }
    }

    @MainActor
    private static func scene(
        claims: ProjectLinkClaimsState, report: InAppEventDeepLinkReport? = nil, events: [InAppEvent]? = nil, buildID: ReleaseBuild.ID? = nil
    ) -> AnyView {
        ProjectLinkClaimsCenter.shared.pin(claims, for: AppIDs.lumen)
        let store = DebugInAppEventsData.store()
        if let report { store.setDeepLinkReport(report, for: AppIDs.lumen) }
        var services = ReleaseDebugScenes.services(.prepare, encryption: .exempt)
        services.inAppEvents = DebugInAppEventsServices(events: events)
        var storePage = DebugStorePageServices()
        storePage.whatsNew = DebugReleaseData.whatsNew.merging([DebugReleaseData.missingLocale: DebugReleaseData.suggestedWhatsNew]) { _, new in new }
        services.storePage = storePage
        ReleaseDebugLaunch.pending = ReleaseDebugLaunch(opensSubmit: true, encryption: .exempt, buildID: buildID)
        return AnyView(DebugMainScene(
            services: services, selectedAppID: AppIDs.lumen, section: .overview, pendingChanges: [], suggestions: FieldSuggestionStore(),
            events: store, release: DebugReleaseData.store(.prepare)
        ))
    }
}
#endif
