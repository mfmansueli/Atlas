//
//  AutoReplyDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Reply Automatically's DEBUG scenes (board 58), on Lumen's reviews.
///
/// - `ar`: on, sending 4★ and 5★: the Brazilian 4★ reply goes out by
///   itself in 42 min, the Japanese 2★ waits for you, one sent today.
/// - `ar-first`: on, but no reply was sent by hand yet, and Claude Code
///   isn't connected; `ar-paused`: paused.
/// - `ar-settings`: off, Reply Automatically… open; `ar-settings-on`: on,
///   open with Save and Turn Off; `ar-free`: Free, open with Upgrade….
/// - `ar-history`: History open, with Undo.
enum AutoReplyDebugScenes {
    typealias Data = DebugReviewsData

    @MainActor private static var loadedScene: String?

    static let ids = ["ar", "ar-first", "ar-paused", "ar-settings", "ar-settings-on", "ar-free", "ar-history"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard ids.contains(id) else { return nil }
        let isFree = id == "ar-free"
        // The scene's view is made again on every pass of the root's body:
        // load the state once, or Save, Pause and Undo would be undone.
        if loadedScene != id {
            loadedScene = id
            let center = AutoReplyCenter.shared
            center.now = { Data.today }
            center.isPro = { !isFree }
            let isOff = id == "ar-settings" || isFree
            center.load(isOff ? AutoReplyArchive() : archive(paused: id == "ar-paused", first: id == "ar-first"), for: DebugFixtures.AppID.lumen)
        }
        let store = Data.store()
        if id != "ar-first" { store.markReplySentByHand() }
        var launch = ReviewsDebugLaunch()
        launch.opensAutoReplySettings = id.hasPrefix("ar-settings") || isFree
        launch.opensAutoReplyHistory = id == "ar-history"
        return ReviewsDebugScenes.scene(store: store, launch: launch, isFree: isFree)
    }

    private static var rule: AutoReplyRule {
        var rule = AutoReplyRule()
        rule.isOn = true
        rule.mode = .sendAllowed
        rule.onSince = Data.today.addingTimeInterval(-6 * 86400)
        rule.signature = "Ana from Lumen"
        return rule
    }

    private static func archive(paused: Bool, first: Bool) -> AutoReplyArchive {
        var archive = AutoReplyArchive()
        archive.rule = rule
        archive.rule.isPaused = paused
        let created = Data.today.addingTimeInterval(-18 * 60)
        // The countdown reads the clock, so it's 42 min from the real now.
        archive.drafts["r-br1"] = AutoReplyDraft(reviewID: "r-br1", state: .scheduled(sendAt: .now.addingTimeInterval(42 * 60)), createdAt: created)
        archive.drafts["r-jp1"] = AutoReplyDraft(reviewID: "r-jp1", state: .needsYou(reason: "2★ replies wait for you"), createdAt: created)
        archive.history = [
            AutoReplyHistoryEntry(
                reviewID: "r-gb1", replyID: "debug-auto-gb1",
                text: "Thank you, that means a lot! A dark widget is on our list.\n— Ana from Lumen", rating: 4,
                reviewer: "pen & paper, United Kingdom", sentAt: Data.today.addingTimeInterval(-3 * 3600), rule: rule.summary
            ),
        ]
        if first { archive.writeProblem = String(localized: "Couldn’t write a reply: Claude Code isn’t connected.") }
        return archive
    }
}
#endif
