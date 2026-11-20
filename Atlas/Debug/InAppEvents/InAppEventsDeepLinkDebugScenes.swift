//
//  InAppEventsDeepLinkDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The DEBUG scenes of an event's details and its deep link
/// (`-AtlasDebugScene <id>`), on Lumen Journal's sample events:
///
/// - `ev-link-none`: the Winter Reflection Challenge without a deep link:
///   "Before App Review" lists it, with Add Deep Link.
/// - `ev-link-suggested`: Claude Code's deep link and purpose for it,
///   waiting for Accept.
/// - `ev-link-unclaimed`: the Mood Calendar's lumen:// link, which
///   Lumen's project doesn't declare ("Lumen Journal doesn't open lumen://
///   links yet"), with Make It Work….
/// - `ev-link-claimed`: the project declares lumen://, nobody checked the
///   event in the code: "Not checked", Check in the Code.
/// - `ev-link-opens`: Claude Code's check: it opens, in build 1.4 (212),
///   tried in Simulator. `ev-link-fails`: it doesn't open yet.
/// - `ev-link-nofolder`: no project folder: Choose the Project Folder….
enum InAppEventsDeepLinkDebugScenes {
    typealias AppIDs = DebugFixtures.AppID
    typealias Data = DebugInAppEventsData

    static let ids = [
        "ev-link-none", "ev-link-suggested", "ev-link-unclaimed", "ev-link-claimed", "ev-link-opens", "ev-link-fails", "ev-link-nofolder",
    ]

    static let folder = "~/Projects/ios/Lumen"

    /// Lumen's project: its app target, and lumen:// when `declaresScheme`.
    static func claims(declaresScheme: Bool) -> ProjectLinkClaimsState {
        .read(folder: folder, claims: ProjectLinkClaims(schemes: declaresScheme ? ["lumen"] : [], targets: ["Lumen"], build: "1.4 (212)"))
    }

    /// Claude Code's check of the Mood Calendar's link.
    static func report(opens: Bool, build: String = "1.4 (212)") -> InAppEventDeepLinkReport {
        InAppEventDeepLinkReport(
            eventID: Data.moodID, deepLink: Data.moodDeepLink, opens: opens,
            shows: opens ? "The Mood Calendar for this month, opened on today" : "The home screen: the link isn’t handled",
            beforeStart: opens ? "The Mood Calendar with “Starts Nov 24” over it" : "",
            needsPremium: false, location: "Lumen/App/LumenApp.swift:48", build: build, testedInSimulator: true,
            problems: opens ? [] : ["LumenApp has no onOpenURL: the link opens the app on its home screen."],
            client: "Claude Code", date: DebugReleaseData.today
        )
    }

    @MainActor
    static func view(for id: String) -> AnyView? {
        let winter = InAppEventsDebugLaunch(eventID: Data.winterID, locale: "en-US")
        let mood = InAppEventsDebugLaunch(eventID: Data.moodID, locale: "en-US")
        switch id {
        case "ev-link-none":
            return scene(winter, claims: claims(declaresScheme: true))
        case "ev-link-suggested":
            return scene(winter, claims: claims(declaresScheme: true), pendingChanges: suggestedDetails())
        case "ev-link-unclaimed":
            return scene(mood, claims: claims(declaresScheme: false))
        case "ev-link-claimed":
            return scene(mood, claims: claims(declaresScheme: true))
        case "ev-link-opens":
            return scene(mood, claims: claims(declaresScheme: true), report: report(opens: true))
        case "ev-link-fails":
            return scene(mood, claims: claims(declaresScheme: true), report: report(opens: false))
        case "ev-link-nofolder":
            return scene(mood, claims: .noFolder)
        default:
            return nil
        }
    }

    /// Claude Code's deep link and purpose for the Winter Reflection
    /// Challenge, waiting for the person.
    @MainActor
    static func suggestedDetails() -> [PendingChange] {
        let builder = InAppEventChangeBuilder(appID: AppIDs.lumen)
        let source = ChangeSource.assistant(client: "Claude Code")
        return [
            builder.detailChange(.deepLink, to: "lumen://challenges/winter-2026", of: Data.winter, appName: "Lumen Journal", source: source),
            builder.detailChange(.purpose, to: InAppEventPurpose.keepActiveUsersInformed.rawValue, of: Data.winter, source: source),
        ].compactMap(\.self)
    }

    @MainActor
    private static func scene(
        _ launch: InAppEventsDebugLaunch, claims: ProjectLinkClaimsState, report: InAppEventDeepLinkReport? = nil,
        pendingChanges: [PendingChange] = []
    ) -> AnyView {
        ProjectLinkClaimsCenter.shared.pin(claims, for: AppIDs.lumen)
        let store = Data.store()
        if let report { store.setDeepLinkReport(report, for: AppIDs.lumen) }
        var services = WorkspaceServices.debug
        services.inAppEvents = DebugInAppEventsServices()
        InAppEventsDebugLaunch.pending = launch
        return AnyView(DebugMainScene(
            services: services, selectedAppID: AppIDs.lumen, section: .inAppEvents, pendingChanges: pendingChanges, events: store
        ))
    }
}
#endif
