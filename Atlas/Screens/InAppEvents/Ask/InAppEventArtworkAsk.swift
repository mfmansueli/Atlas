//
//  InAppEventArtworkAsk.swift
//  Atlas
//

import Foundation

/// Make the Artwork, Ask for Changes… and Make Them Move start Claude Code
/// through the toolbar (board 56): the request goes to the toolbar's
/// Autopilot button, which says Working… until the run ends, and the
/// app's asking buttons say so too. The concepts still fill in on the
/// event's page, which says when they're ready; the toolbar's toast speaks
/// only when the run failed. Another request already running doesn't
/// stop the artwork: Claude Code starts all the same.
@MainActor
enum InAppEventArtworkAsk {
    /// "In-App Events · Winter Reflection 2026".
    static func subject(eventName: String) -> String {
        String(localized: "In-App Events · \(eventName)", comment: "kind:label")
    }

    /// The toolbar's request for the event's artwork.
    static func ask(app: StoreApp, eventName: String, client: String) -> AssistantAsk {
        AssistantAsk(appID: app.id, client: client, subject: subject(eventName: eventName))
    }

    /// Sends `ask` to the toolbar, then starts Claude Code with `start`;
    /// returns its run, or nil when it didn't start (the flow copies the
    /// prompt then).
    static func launch(
        _ ask: AssistantAsk,
        purpose: ClaudeCodeRunPurpose,
        prompt: String,
        askCenter: AssistantAskCenter,
        reduceMotion: Bool,
        start: (ClaudeCodeRunPurpose, String) async -> UUID?
    ) async -> UUID? {
        let client = ask.client
        let sent = askCenter.send(ask, from: nil, reduceMotion: reduceMotion) { run in
            ending(run, client: client)
        }
        let runID = await start(purpose, prompt)
        guard sent else { return runID }
        if let runID {
            askCenter.attach(runID: runID, to: ask.id)
        } else {
            askCenter.cancel(ask.id)
        }
        return runID
    }

    /// The toolbar's toast when the run ends: nothing when it finished
    /// (the page says the concepts are ready), why when it failed.
    static func ending(_ run: ClaudeCodeRun, client: String) -> String? {
        run.phase == .finished ? nil : AssistantAskCenter.endingText(run, client: client, done: "")
    }
}
