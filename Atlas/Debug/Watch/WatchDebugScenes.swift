//
//  WatchDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Look for Improvements' DEBUG scenes (`-AtlasDebugScene <id>`): what one
/// check finds and decides for the sample apps, and the prompt the run
/// would start with, without starting Claude Code. "Now" is Nov 25, 2026.
///
/// - `watch`: 10:00, on and Pro: Lumen Journal's run is planned (What's
///   New, an event, reviews); Habitat's waits for it (another run); Tempo's
///   findings are Atlas's own (submission blocked).
/// - `watch-quiet`: 23:00, quiet hours.
/// - `watch-cap`: three runs today already; Habitat's crash findings
///   paused after three dismissals, asking Keep Suggesting? once.
enum WatchDebugScenes {
    static let ids = ["watch", "watch-quiet", "watch-cap"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard let scene = WatchDebugData.Scene(rawValue: id) else { return nil }
        let center = WatchDebugData.center(for: scene)
        let plan = center.plan(WatchDebugData.inputs(now: center.now()), context: WatchDebugData.context, dedupe: [:])
        center.setLastPlan(plan)
        return AnyView(WatchDebugReportView(center: center, plan: plan))
    }
}
#endif
