//
//  AssistantAskCenter.swift
//  Atlas
//

import AppKit
import SwiftUI

/// The requests sent from asking buttons, one at a time for each app
/// (board 56). Sending one turns the app's asking buttons to "Claude Code Is
/// Working…", flies a token from the button to the toolbar's Assistant
/// button, and makes that button say Working…; when the run ends, the
/// window's toast says what was suggested and where.
@MainActor
@Observable
final class AssistantAskCenter {
    static let shared = AssistantAskCenter()

    /// The running request of each app.
    private(set) var asks: [StoreApp.ID: AssistantAsk] = [:]
    /// The last ask that ended with something to say, for the toast.
    private(set) var finished: AssistantAskFinish?

    /// The toolbar's Assistant button, where the token lands.
    @ObservationIgnored let toolbarAnchor = AskAnchor()
    /// Draws the flight from one frame on screen to the other in a window;
    /// false when it can't, so the toolbar works at once. Tests give
    /// their own.
    @ObservationIgnored var fly: @MainActor (_ from: CGRect?, _ to: CGRect?, _ window: NSWindow?) -> Bool
    /// How long the token takes before the toolbar says Working….
    @ObservationIgnored var landing: Duration = .milliseconds(Int(AskTokenPath.landing * 1000))
    /// The last token in the air, until it lands (tests wait for it).
    @ObservationIgnored private(set) var flight: Task<Void, Never>?
    /// Says the send out loud.
    @ObservationIgnored var announce: @MainActor (String) -> Void = { AccessibilityNotification.Announcement($0).post() }
    /// What each ask says when its run ends; nil says nothing.
    @ObservationIgnored private var endings: [AssistantAsk.ID: @MainActor (ClaudeCodeRun) -> String?] = [:]

    init() {
        let overlay = AskFlightOverlay()
        fly = { overlay.fly(from: $0, to: $1, in: $2) }
    }

    func ask(for appID: StoreApp.ID) -> AssistantAsk? { asks[appID] }

    /// Sends `ask` from the button behind `source`. False when the app has
    /// a request running already. `onRunEnded` gives the toast's text once
    /// its run ends (nil for none); the run is attached with
    /// `attach(runID:to:)`.
    @discardableResult
    func send(
        _ ask: AssistantAsk, from source: AskAnchor?, reduceMotion: Bool,
        onRunEnded: @escaping @MainActor (ClaudeCodeRun) -> String? = { _ in nil }
    ) -> Bool {
        guard asks[ask.appID] == nil else { return false }
        var ask = ask
        ask.phase = .sending
        asks[ask.appID] = ask
        endings[ask.id] = onRunEnded
        announce(ask.announcement)
        let flies = !reduceMotion && fly(source?.screenFrame, toolbarAnchor.screenFrame, source?.view?.window)
        guard flies else {
            arrive(ask.id, appID: ask.appID)
            return true
        }
        let landing = landing
        flight = Task { [weak self] in
            try? await Task.sleep(for: landing)
            self?.arrive(ask.id, appID: ask.appID)
        }
        return true
    }

    /// The token landed: the toolbar works.
    private func arrive(_ id: AssistantAsk.ID, appID: StoreApp.ID) {
        guard asks[appID]?.id == id else { return }
        asks[appID]?.phase = .working
    }

    /// The run Atlas started for the ask.
    func attach(runID: ClaudeCodeRun.ID, to id: AssistantAsk.ID) {
        guard let appID = asks.first(where: { $0.value.id == id })?.key else { return }
        asks[appID]?.runID = runID
    }

    /// Ends the ask; `text` goes in the window's toast.
    func finish(_ id: AssistantAsk.ID, text: String?) {
        guard let (appID, ask) = asks.first(where: { $0.value.id == id }) else { return }
        asks[appID] = nil
        endings[id] = nil
        if let text { finished = AssistantAskFinish(appID: appID, subject: ask.subject, text: text) }
    }

    /// Ends the ask without a toast: nothing was sent after all.
    func cancel(_ id: AssistantAsk.ID) { finish(id, text: nil) }

    /// A Claude Code run ended: its ask, if it had one, ends with what the
    /// button says about it.
    func runEnded(_ run: ClaudeCodeRun) {
        guard let ask = asks.values.first(where: { $0.runID == run.id }) else { return }
        let text = endings[ask.id]?(run)
        finish(ask.id, text: text)
    }

    /// The toast's text for an ask whose run ended: `done` when it
    /// finished, why when it failed, nothing when the person stopped it.
    static func endingText(_ run: ClaudeCodeRun, client: String, done: String) -> String? {
        switch run.phase {
        case .finished: done
        case .failed: String(localized: "\(client) stopped before it was done. Its button says why.")
        case .stopped, .starting, .working: nil
        }
    }
}
