//
//  TourDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The DEBUG scenes of the first-run tour (`-AtlasDebugScene <id>`), as on
/// the design's board 63. Each is Lumen Journal's Overview with the
/// sidebar's counts; the app menu itself is `nav-apps`.
///
/// - `tour`: a first run: the tour starts by itself on its first tip, the
///   app switcher.
/// - `tour-2` … `tour-5`: the sections, the Autopilot button, Review &
///   Push and the sidebar's Settings row.
enum TourDebugScenes {
    static let ids = ["tour", "tour-2", "tour-3", "tour-4", "tour-5"]

    /// The scene that shows `step`.
    static func id(for step: TourStep) -> String {
        step == .apps ? "tour" : "tour-\(step.number)"
    }

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard ids.contains(id) else { return nil }
        if id == "tour" {
            NavigationDebugLaunch.startsTourOnFirstRun = true
        } else {
            NavigationDebugLaunch.tourStep = TourStep.allCases.first { Self.id(for: $0) == id }
        }
        return AnyView(DebugMainScene(
            services: ReleaseDebugScenes.services(.prepare), section: .overview, suggestions: SuggestionsDebugData.store(),
            release: DebugReleaseData.store(.prepare)
        ))
    }
}
#endif
