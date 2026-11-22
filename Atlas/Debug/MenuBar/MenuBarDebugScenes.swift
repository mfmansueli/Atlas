//
//  MenuBarDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Menu bar DEBUG scenes (`-AtlasDebugScene <id>`), as the design's board
/// 46 draws them. The menu sits in the window on its own (a scene has no
/// menu bar icon), and its lines act on the scene: Pause turns into
/// Resume, Check Now runs a pretend check for 3 s, the rest say what they
/// would open in a line under the menu.
///
/// - `mb-quiet`: nothing running, nothing waiting.
/// - `mb-running`: a push and Autopilot at work, with what needs you.
/// - `mb-needs`: nothing running, four things waiting.
/// - `mb-paused`, `mb-offline`: paused; the key refused.
/// - `mb-autoreply`: Reply Automatically on, a review left for you.
/// - `mb-note`: "Atlas is still running", the first time the window closes.
/// - `mb-glyphs`: the icon in every state, and the working loop's frames.
/// - `mb-live`: the sample library with Atlas running as a real launch
///   does: the menu bar icon and its menu, the window that hides when
///   closed, the note, the checks (against the canned services). Settings
///   and data stay in memory.
enum MenuBarDebugScenes {
    static let ids = ["mb-quiet", "mb-running", "mb-needs", "mb-paused", "mb-offline", "mb-autoreply", "mb-note", "mb-glyphs", "mb-live"]

    /// Whether the scene runs `AtlasLifecycle` as a real launch.
    static func isLive(_ id: String) -> Bool {
        id == "mb-live"
    }

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard ids.contains(id) else { return nil }
        switch id {
        case "mb-glyphs": return AnyView(MenuBarGlyphGallery())
        case "mb-live": return AnyView(DebugMainScene())
        case "mb-note": return AnyView(MenuBarDebugScene(note: true, snapshot: snapshot(for: "mb-quiet")))
        default: return AnyView(MenuBarDebugScene(note: false, snapshot: snapshot(for: id)))
        }
    }

    static let checkLine = "Last checked today at 18:20 · next check at 19:20"

    static func snapshot(for id: String) -> MenuBarSnapshot {
        switch id {
        case "mb-running":
            MenuBarSnapshot(jobs: runningJobs, needs: Array(needs.prefix(2)), checkLine: checkLine, reviewPushCount: 23)
        case "mb-needs":
            MenuBarSnapshot(needs: needs, checkLine: checkLine, reviewPushCount: 4)
        case "mb-paused":
            MenuBarSnapshot(checkLine: "Last checked today at 18:20 · paused", reviewPushCount: 4, isPaused: true)
        case "mb-autoreply":
            MenuBarSnapshot(
                needs: [BackgroundNeed(
                    id: "autoreply-lumen", title: "1 review needs your reply", detail: "Lumen Journal · Reply Automatically left them for you",
                    destination: .section(.reviews, appID: DebugFixtures.AppID.lumen)
                )],
                checkLine: checkLine, reviewPushCount: 4, autoReplyPaused: false
            )
        case "mb-offline":
            MenuBarSnapshot(
                checkLine: checkLine, reviewPushCount: 4,
                connectionProblem: "App Store Connect rejected this key (401)."
            )
        default:
            MenuBarSnapshot(checkLine: checkLine)
        }
    }

    static let runningJobs = [
        BackgroundJob(
            id: "push", kind: .push, title: "Pushing to App Store Connect", fraction: 0.61,
            detail: "14 of 23 changes · Lumen Journal · about 1 min left"
        ),
        BackgroundJob(
            id: "autopilot-\(DebugFixtures.AppID.habitat)", kind: .autopilot, title: "Autopilot · Capturing", fraction: 0.35,
            detail: "Habitat — Plant Care · 9 of 26 captures"
        ),
    ]

    static let needs = [
        BackgroundNeed(
            id: "autopilot-\(DebugFixtures.AppID.tempo)", title: "Choose the look for Tempo Metronome’s screenshots",
            detail: "Autopilot waits here", destination: .section(.screenshots, appID: DebugFixtures.AppID.tempo)
        ),
        BackgroundNeed(
            id: "release-\(DebugFixtures.AppID.lumen)", title: "Lumen Journal 2.4 was approved",
            detail: "You chose to release it yourself · Release…", destination: .version(appID: DebugFixtures.AppID.lumen)
        ),
        BackgroundNeed(
            id: "reviews-\(DebugFixtures.AppID.lumen)", title: "6 reviews need a reply",
            detail: "Lumen Journal · Replies are suggested in each language",
            destination: .section(.reviews, appID: DebugFixtures.AppID.lumen)
        ),
        BackgroundNeed(
            id: "suggestions-\(DebugFixtures.AppID.habitat)", title: "12 suggestions to review",
            detail: "Habitat — Plant Care · Nothing changes until you accept it",
            destination: .section(.overview, appID: DebugFixtures.AppID.habitat)
        ),
    ]
}
#endif
