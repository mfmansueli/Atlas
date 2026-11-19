//
//  InAppEventsDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The In-App Events DEBUG scenes (`-AtlasDebugScene <id>`), board 40
/// without artwork runs (those are `EventArtworkDebugScenes`).
///
/// - `ev`: the Winter Reflection Challenge's page in German, nine
///   languages suggested; `ev-br` (Portuguese: renamed, and why).
/// - `ev-mood`: the event that goes with 1.4; `ev-ended`: Gratitude Week,
///   with how it did.
/// - `ev-new`: the New Event sheet; `ev-empty`: no events; `ev-error`.
/// - `ev-art`: Claude Code's card (every language) and details page
///   (English) waiting in Images and video, in English.
enum InAppEventsDebugScenes {
    typealias AppIDs = DebugFixtures.AppID
    typealias Data = DebugInAppEventsData

    static let ids = ["ev", "ev-br", "ev-mood", "ev-ended", "ev-new", "ev-empty", "ev-error", "ev-art"]

    /// The scenes that open the sample events on one event and language.
    private static let launches: [String: InAppEventsDebugLaunch] = [
        "ev": InAppEventsDebugLaunch(),
        "ev-br": InAppEventsDebugLaunch(locale: "pt-BR"),
        "ev-mood": InAppEventsDebugLaunch(eventID: Data.moodID, locale: "en-US"),
        "ev-ended": InAppEventsDebugLaunch(eventID: Data.gratitudeID, locale: "en-US"),
        "ev-new": InAppEventsDebugLaunch(opensEvent: false, opensNewEvent: true),
    ]

    @MainActor
    static func view(for id: String) -> AnyView? {
        if let launch = launches[id] { return scene(launch) }
        switch id {
        case "ev-empty":
            return scene(services: DebugInAppEventsServices(isEmpty: true), store: InAppEventsStore())
        case "ev-art":
            return scene(InAppEventsDebugLaunch(locale: "en-US"), pendingChanges: DebugInAppEventArtwork.changes())
        case "ev-error":
            let failing = DebugInAppEventsServices(error: .server(statusCode: 500, detail: "The events couldn’t be read."))
            return scene(services: failing, store: InAppEventsStore())
        default:
            return nil
        }
    }

    @MainActor
    private static func scene(
        _ launch: InAppEventsDebugLaunch = InAppEventsDebugLaunch(),
        services events: DebugInAppEventsServices = DebugInAppEventsServices(),
        store: InAppEventsStore? = nil,
        pendingChanges: [PendingChange] = []
    ) -> AnyView {
        var services = WorkspaceServices.debug
        services.inAppEvents = events
        InAppEventsDebugLaunch.pending = launch
        return AnyView(DebugMainScene(
            services: services, selectedAppID: AppIDs.lumen, section: .inAppEvents, pendingChanges: pendingChanges, events: store ?? Data.store()
        ))
    }
}
#endif
