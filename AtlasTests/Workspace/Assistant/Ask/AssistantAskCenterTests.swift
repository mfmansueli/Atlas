//
//  AssistantAskCenterTests.swift
//  AtlasTests
//

import AppKit
import Foundation
import Testing
@testable import Atlas

/// Requests from asking buttons: one at a time for each app, Working… once
/// the token lands, and a toast that says where the suggestions are when
/// the run ends.
@MainActor
@Suite("AssistantAskCenter")
struct AssistantAskCenterTests {
    private func center(flies: Bool = false, landing: Duration = .milliseconds(20)) -> (AssistantAskCenter, Box) {
        let center = AssistantAskCenter()
        let box = Box()
        center.fly = { _, _, _ in flies }
        center.landing = landing
        center.announce = { box.said.append($0) }
        return (center, box)
    }

    final class Box {
        var said: [String] = []
    }

    private func ask(_ appID: StoreApp.ID = "1", subject: String = "Store Page") -> AssistantAsk {
        AssistantAsk(appID: appID, client: "Claude Code", subject: subject)
    }

    private func run(_ id: UUID, phase: ClaudeCodeRun.Phase) -> ClaudeCodeRun {
        var run = ClaudeCodeRun(id: id, appID: "1", appName: "Lumen", purpose: .ask(area: "Store Page"), prompt: "", workingDirectory: "/tmp", startedAt: .now)
        run.phase = phase
        return run
    }

    @Test func oneRequestAtATimeForEachApp() {
        let (center, _) = center()
        #expect(center.send(ask("1"), from: nil, reduceMotion: false))
        #expect(!center.send(ask("1", subject: "In-App Events"), from: nil, reduceMotion: false))
        #expect(center.ask(for: "1")?.subject == "Store Page")
        #expect(center.send(ask("2"), from: nil, reduceMotion: false))
    }

    @Test func withoutAFlightTheToolbarWorksAtOnceAndVoiceOverHearsIt() {
        let (center, box) = center(flies: false)
        center.send(ask(subject: "In-App Events · Winter Reflection 2026"), from: nil, reduceMotion: false)
        #expect(center.ask(for: "1")?.phase == .working)
        #expect(box.said == ["Sent to Claude Code: In-App Events, Winter Reflection 2026. The Assistant button in the toolbar shows it’s working."])
        #expect(center.ask(for: "1")?.toolbarLabel == "Assistant, Claude Code is working on In-App Events, Winter Reflection 2026")
        #expect(center.ask(for: "1")?.busyTitle == "Claude Code Is Working…")
    }

    @Test func reduceMotionSkipsTheFlight() {
        var flew = false
        let (center, _) = center()
        center.fly = { _, _, _ in
            flew = true
            return true
        }
        center.send(ask(), from: nil, reduceMotion: true)
        #expect(!flew)
        #expect(center.ask(for: "1")?.phase == .working)
    }

    @Test func theToolbarWorksOnceTheTokenLands() async throws {
        let (center, _) = center(flies: true)
        center.send(ask(), from: nil, reduceMotion: false)
        #expect(center.ask(for: "1")?.phase == .sending)
        try await Task.sleep(for: .milliseconds(200))
        #expect(center.ask(for: "1")?.phase == .working)
    }

    @Test func theRunEndingEndsTheAskWithWhatTheButtonSays() {
        let (center, _) = center()
        let sent = ask()
        center.send(sent, from: nil, reduceMotion: false) { run in
            AssistantAskCenter.endingText(run, client: "Claude Code", done: "Claude Code finished Store Page.")
        }
        let runID = UUID()
        center.attach(runID: runID, to: sent.id)
        // Another run ending changes nothing.
        center.runEnded(run(UUID(), phase: .finished))
        #expect(center.ask(for: "1") != nil)
        center.runEnded(run(runID, phase: .finished))
        #expect(center.ask(for: "1") == nil)
        #expect(center.finished?.text == "Claude Code finished Store Page.")
        #expect(center.finished?.appID == "1")
    }

    @Test func aStoppedRunSaysNothingAndAFailedOneSaysWhereItsOutputIs() {
        let stopped = run(UUID(), phase: .stopped)
        #expect(AssistantAskCenter.endingText(stopped, client: "Claude Code", done: "Done.") == nil)
        let failed = run(UUID(), phase: .failed(.claudeMissing))
        #expect(AssistantAskCenter.endingText(failed, client: "Claude Code", done: "Done.")?.contains("stopped before it was done") == true)
    }

    @Test func cancellingEndsTheAskWithoutAToast() {
        let (center, _) = center()
        let sent = ask()
        center.send(sent, from: nil, reduceMotion: false)
        center.cancel(sent.id)
        #expect(center.ask(for: "1") == nil)
        #expect(center.finished == nil)
        #expect(center.send(ask(), from: nil, reduceMotion: false))
    }

    /// An ask from the Store Page ends its suggestion request when the run
    /// ends, with where the suggestions are.
    @Test func aSuggestionAskEndsItsRequestWithWhereTheSuggestionsAre() {
        let store = FieldSuggestionStore()
        let claude = SuggestionSource.assistant(client: "Claude Code")
        store.beginRequest(appID: "1", area: .storePage, client: "Claude Code", prompt: "Suggest…")
        store.add(appID: "1", target: .storePage(.englishUS, .whatsNew), value: "One", reason: "", source: claude)
        store.add(appID: "1", target: .storePage(.german, .whatsNew), value: "Zwei", reason: "", source: claude)
        let text = SuggestionAskButton.ended(run(UUID(), phase: .finished), appID: "1", area: .storePage, suggestions: store)
        #expect(text == "Claude Code finished Store Page: 2 suggestions, marked in purple on the fields. Nothing changes until you accept them.")
        #expect(store.request == nil)

        store.beginRequest(appID: "1", area: .storePage, client: "Claude Code", prompt: "Suggest…")
        let none = SuggestionAskButton.ended(run(UUID(), phase: .finished), appID: "1", area: .storePage, suggestions: store)
        #expect(none == "Claude Code finished without sending suggestions.")
        #expect(store.request == nil)
    }
}
