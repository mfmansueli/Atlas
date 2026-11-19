//
//  EventArtworkDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The DEBUG scenes of boards 40 and 47 with artwork, on the Winter
/// Reflection Challenge in English unless said:
///
/// - Gallery and page: `ev-list` (three concepts ready), `ev-event`,
///   `ev-menu` (the other events), `ev-de`, `ev-details`, `ev-ar` and
///   `ev-accepted` (the concept used; the board's `ev-done`, a name
///   Suggest Everything already has).
/// - Artwork: `ev-missing`, `ev-missing-details`, `ev-making` (one of
///   three ready), `ev-b`, `ev-used`, `ev-change`, `ev-free` (Make the
///   Artwork is Pro).
/// - Viewer: `ev-view`, `ev-view-b`, `ev-view-details`, `ev-view-clean`
///   (no text), `ev-view-safe` (Text Area), `ev-view-de`, `ev-view-ar`,
///   `ev-view-ask`, `ev-view-redo`, `ev-view-making`, `ev-view-motion`,
///   `ev-full`, `ev-full-details`.
/// - The Brief: `ea-brief`, `ea-brief-opts` (words and motion on),
///   `ea-brief-nods` (no design project: templates first); `ea-files`
///   (the person's files, in the viewer).
enum EventArtworkDebugScenes {
    typealias Concepts = DebugEventArtworkConcepts

    static let ids = [
        "ev-list", "ev-event", "ev-menu", "ev-de", "ev-details", "ev-ar", "ev-accepted",
        "ev-missing", "ev-missing-details", "ev-making", "ev-b", "ev-used", "ev-change", "ev-free",
        "ev-view", "ev-view-b", "ev-view-details", "ev-view-clean", "ev-view-safe", "ev-view-de", "ev-view-ar", "ev-view-ask",
        "ev-view-redo", "ev-view-making", "ev-view-motion", "ev-full", "ev-full-details",
        "ea-brief", "ea-brief-opts", "ea-brief-nods", "ea-files",
    ]

    /// What one scene loads: its runs, how the page opens, the setup for
    /// the event's flow, and changes already in Review & Push.
    private struct Scene {
        var setup = DebugEventArtworkSetup()
        var launch = InAppEventsDebugLaunch(locale: "en-US")
        var runs: [EventArtworkRun] = []
        var pending: [PendingChange] = []
        var isFree = false
    }

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard ids.contains(id) else { return nil }
        let studio = EventArtworkStudio.shared
        let scene = scene(id)
        studio.load(scene.runs)
        EventArtworkSheetSize.debugHasDesignSystem = scene.setup.hasDesignSystem
        DebugEventArtworkSetup.pending = scene.setup
        InAppEventsDebugLaunch.pending = scene.launch
        var services = WorkspaceServices.debug
        services.inAppEvents = DebugInAppEventsServices()
        return AnyView(DebugMainScene(
            services: services, selectedAppID: Concepts.appID, section: .inAppEvents, pendingChanges: scene.pending,
            events: DebugInAppEventsData.store(), artwork: studio, isFree: scene.isFree
        ))
    }

    @MainActor
    private static func scene(_ id: String) -> Scene {
        if id.hasPrefix("ea-brief") { return brief(id) }
        if id.hasPrefix("ev-view") || id.hasPrefix("ev-full") { return viewer(id) }
        var scene = Scene()
        switch id {
        case "ev-list":
            scene.runs = [ready()]
            scene.launch.opensEvent = false
        case "ev-event", "ev-menu":
            scene.runs = [ready()]
            scene.launch.opensMenu = id == "ev-menu"
        case "ev-de":
            scene.runs = [ready(picked: "a")]
            scene.launch.locale = "de-DE"
        case "ev-details":
            scene.runs = [ready(picked: "a")]
            scene.launch.previewKind = .details
        case "ev-b": scene.runs = [ready(picked: "b")]
        case "ev-making": scene.runs = [Concepts.run(step: .making, ready: 1)]
        case "ev-missing-details": scene.launch.previewKind = .details
        case "ev-free": scene.isFree = true
        case "ev-used", "ev-ar", "ev-accepted", "ev-change":
            scene.runs = [used()]
            scene.pending = Concepts.usedChanges()
            scene.launch.acceptsAll = id != "ev-ar"
            if id == "ev-ar" { scene.launch.locale = "ar-SA" }
            if id == "ev-accepted" { scene.launch.locale = "de-DE" }
            if id == "ev-change" {
                scene.setup.configure = { flow in
                    flow.change()
                    flow.preview("c")
                }
            }
        case "ea-files":
            let run = files()
            scene.runs = [run]
            scene.setup.configure = { flow in
                flow.isChanging = false
                flow.openViewer(conceptID: EventArtworkFlow.filesConceptID, kind: .card, locale: "en-US", showsTextArea: true)
            }
        default: break
        }
        return scene
    }

    /// Three concepts ready, `picked` clicked (none: Claude's pick
    /// shows).
    @MainActor
    private static func ready(picked: EventArtworkConcept.ID? = nil) -> EventArtworkRun {
        var run = Concepts.run(step: .choose)
        run.pickedID = picked
        return run
    }

    /// Concept `a` used, its pair in Review & Push.
    @MainActor
    private static func used() -> EventArtworkRun {
        var run = Concepts.run(step: .check)
        run.usedConceptID = "a"
        run.usedAt = DebugReviewsData.today.addingTimeInterval(-60)
        run.queuedChangeIDs = Concepts.usedChanges().map(\.id)
        return run
    }

    /// The Brief: as written, with words and motion on, or without a design
    /// project (templates first).
    private static func brief(_ id: String) -> Scene {
        var scene = Scene()
        scene.launch.opensArtwork = true
        if id == "ea-brief-opts" {
            scene.setup.configure = { flow in flow.edit { $0.wordsInArt = true; $0.makesMotion = true } }
        }
        if id == "ea-brief-nods" { scene.setup.hasDesignSystem = false }
        return scene
    }

    /// The viewer over the window, on a concept, an image and a language;
    /// in full screen for `ev-full*`.
    @MainActor
    private static func viewer(_ id: String) -> Scene {
        var scene = Scene()
        var run = Concepts.run(step: .choose)
        var concept = "a"
        var kind = InAppEventMedia.Kind.card
        var locale = "en-US"
        switch id {
        case "ev-view-b": concept = "b"
        case "ev-view-details":
            concept = "c"
            kind = .details
        case "ev-view-de": locale = "de-DE"
        case "ev-view-ar", "ev-full-details":
            concept = "b"
            kind = .details
            if id == "ev-view-ar" { locale = "ar-SA" }
        case "ev-view-redo":
            run.step = .making
            run.revisingID = "a"
            run.revisionRequest = "Warmer, with more snow on the path"
        case "ev-view-making":
            run = Concepts.run(step: .making, ready: 2)
            concept = "b"
        case "ev-view-motion":
            run = motion()
            addLoops(of: run)
        default: break
        }
        scene.runs = [run]
        scene.setup.configure = { flow in
            flow.openViewer(conceptID: concept, kind: kind, locale: locale)
            switch id {
            case "ev-view-clean": flow.viewer?.showsText = false
            case "ev-view-safe", "ev-view-de": flow.viewer?.showsTextArea = true
            case "ev-view-ask": flow.openAsk()
            case "ev-full", "ev-full-details": flow.viewer?.isFull = true
            default: break
            }
        }
        return scene
    }

    /// Three concepts, the first with a moving version of each image.
    @MainActor
    private static func motion() -> EventArtworkRun {
        var run = Concepts.run(step: .choose)
        run.makesMotion = true
        return run
    }

    /// Writes real short loops of the pick's images and hands them to the
    /// run once it's in the studio, so the viewer plays them
    /// (`DebugEventArtworkLoops`).
    @MainActor
    private static func addLoops(of run: EventArtworkRun) {
        let key = EventArtworkRun.Key(appID: run.appID, eventID: run.eventID)
        guard let stills = run.concepts.first?.stills else { return }
        Task { @MainActor in
            let videos = await DebugEventArtworkLoops.write(for: stills)
            EventArtworkStudio.shared.update(key) { run in
                guard !run.concepts.isEmpty else { return }
                run.concepts[0].videos = videos
            }
        }
    }

    /// The person's own files, just chosen.
    @MainActor
    private static func files() -> EventArtworkRun {
        var run = Concepts.run(step: .check, ready: 0)
        if var files = Concepts.all().first {
            files.id = EventArtworkFlow.filesConceptID
            files.name = String(localized: "Your files")
            files.why = ""
            files.isPick = false
            files.source = .files
            run.concepts = [files]
            run.pickedID = files.id
        }
        return run
    }
}
#endif
