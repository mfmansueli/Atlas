//
//  BackgroundWorkTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@MainActor
@Suite("BackgroundWork")
struct BackgroundWorkTests {
    private let now = AutopilotTestFixtures.now
    private let lumen = DebugFixtures.apps.first { $0.id == DebugFixtures.AppID.lumen }!
    private let tempo = DebugFixtures.apps.first { $0.id == DebugFixtures.AppID.tempo }!

    private func defaults() -> UserDefaults {
        let name = "BackgroundWorkTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func work(
        autopilot: AutopilotCenter = AutopilotCenter(),
        preferences: AppPreferences = AppPreferences(defaults: nil),
        artwork: EventArtworkStudio = EventArtworkStudio(),
        defaults: UserDefaults? = nil,
        clock: @escaping () -> Date
    ) -> BackgroundWork {
        BackgroundWork(
            push: PushController(queue: ChangeQueue(), history: PushHistory()),
            changes: ChangeQueue(),
            suggestions: FieldSuggestionStore(),
            preferences: preferences,
            autopilot: autopilot,
            reviews: ReviewsStore(),
            releases: ReleaseStore(),
            analytics: AnalyticsStore(),
            artwork: artwork,
            defaults: defaults,
            now: clock
        )
    }

    // MARK: - Event artwork (board 47)

    /// Claude drawing behind a hidden sheet is a job; its concepts
    /// waiting to be chosen are a "Needs you" line, the dot on the icon.
    @Test func eventArtworkIsAJobThenANeed() throws {
        let artwork = EventArtworkStudio()
        var run = EventArtworkRun(
            appID: lumen.id, eventID: "winter", eventName: "Winter Reflection 2026", brief: "Snow.", style: .newLook, locales: ["en-US"]
        )
        run.step = .making
        run.isHidden = true
        artwork.begin(run)
        let work = work(artwork: artwork) { [now] in now }
        work.library = [lumen]
        let job = try #require(work.snapshot.jobs.first)
        #expect(job.kind == .eventArtwork)
        #expect(job.title == "Claude · Winter Reflection 2026")
        #expect(job.detail == "0 of 3 concepts ready")
        #expect(work.isBusy)
        #expect(work.needs.isEmpty)
        let concept = EventArtworkConcept(id: "a", name: "Path", why: "", client: "Claude Code", stills: [], arrivedAt: now)
        artwork.update(run.key) { run in
            run.step = .choose
            run.concepts = [concept, concept, concept]
        }
        #expect(work.snapshot.jobs.isEmpty)
        let need = try #require(work.needs.first)
        #expect(need.title == "3 concepts are ready for “Winter Reflection 2026”")
        #expect(need.detail == "Choose one to finish the event’s images")
        #expect(need.destination == .eventArtwork(appID: lumen.id, eventID: "winter"))
        #expect(work.snapshot.state == .needsYou)
    }

    @Test func quietWithNothingRunningOrWaiting() {
        let work = work { [now] in now }
        work.library = [lumen]
        let snapshot = work.snapshot
        #expect(snapshot.jobs.isEmpty)
        #expect(snapshot.needs.isEmpty)
        #expect(snapshot.state == .idle)
        #expect(snapshot.quietTitle == "Everything is up to date")
        #expect(!work.isBusy)
    }

    @Test func anAutopilotRunWaitingOnThePersonIsANeed() {
        // The fixtures' runs are Lumen Journal's.
        let run = AutopilotTestFixtures.run(.choose)
        let work = work(autopilot: AutopilotCenter(runs: [lumen.id: run])) { [now] in now }
        work.library = [lumen, tempo]
        #expect(work.needs.map(\.title) == ["Choose the look for Lumen Journal’s screenshots"])
        #expect(work.needs.first?.destination == .section(.screenshots, appID: lumen.id))
        #expect(work.iconState == .needsYou)
    }

    @Test func anAutopilotRunAtWorkIsAJobUntilItGoesQuiet() {
        let run = AutopilotTestFixtures.run(.capture)
        let work = work(autopilot: AutopilotCenter(runs: [lumen.id: run])) { [now] in now }
        work.library = [lumen]
        let jobs = work.jobs(at: now.addingTimeInterval(60))
        #expect(jobs.map(\.kind) == [.autopilot])
        #expect(jobs.first?.title.hasPrefix("Autopilot · ") == true)
        #expect(work.isBusy)
        // Nothing heard for longer than the limit: its Claude Code stopped.
        #expect(work.jobs(at: now.addingTimeInterval(BackgroundWork.autopilotQuietLimit + 60)).isEmpty)
    }

    @Test func checkNowRecordsWhenAndShowsAsAJobMeanwhile() async {
        let work = work { [now] in now }
        var kindsDuringCheck: [BackgroundJob.Kind] = []
        work.checkHandler = { [work] in
            kindsDuringCheck = work.jobs(at: .now).map(\.kind)
            return nil
        }
        await work.check()
        #expect(kindsDuringCheck == [.check])
        #expect(work.lastCheckedAt == now)
        #expect(work.connectionProblem == nil)
        #expect(!work.isChecking)
    }

    @Test func aRefusedKeyIsCantConnectUntilACheckWorks() async {
        let work = work { [now] in now }
        var answer: String? = "App Store Connect rejected this key (401)."
        work.checkHandler = { answer }
        await work.check()
        #expect(work.iconState == .cantConnect)
        #expect(work.snapshot.quietTitle == "App Store Connect rejected this key (401).")
        answer = nil
        await work.check()
        #expect(work.iconState == .idle)
    }

    @Test func withoutAWindowToCheckFromNothingHappens() async {
        let work = work { [now] in now }
        await work.check()
        #expect(work.lastCheckedAt == nil)
    }

    @Test func pausingIsRememberedAndStopsTheSchedule() {
        let defaults = defaults()
        let work = work(defaults: defaults) { [now] in now }
        #expect(work.nextCheckAt == now)
        work.setPaused(true)
        #expect(work.iconState == .paused)
        #expect(work.nextCheckAt == nil)
        #expect(work.snapshot.checkLine == "Not checked yet · paused")
        let relaunched = self.work(defaults: defaults) { [now] in now }
        #expect(relaunched.isPaused)
    }

    @Test func theLastCheckIsRemembered() async {
        let defaults = defaults()
        let work = work(defaults: defaults) { [now] in now }
        work.checkHandler = { nil }
        await work.check()
        let relaunched = self.work(defaults: defaults) { [now] in now }
        #expect(relaunched.lastCheckedAt == now)
        #expect(relaunched.nextCheckAt == now.addingTimeInterval(3600))
    }

    @Test func onlyWhenAskedHasNoNextCheck() {
        let preferences = AppPreferences(defaults: nil)
        preferences.checkInterval = .onlyWhenAsked
        let work = work(preferences: preferences) { [now] in now }
        #expect(work.nextCheckAt == nil)
        #expect(work.snapshot.checkLine == "Not checked yet · checks only when you ask")
    }

    @Test func openingGoesThroughTheWindow() {
        let work = work { [now] in now }
        var opened: [BackgroundDestination] = []
        work.openHandler = { opened.append($0) }
        work.open(.reviewPush)
        #expect(opened == [.reviewPush])
    }

    @Test func detachForgetsTheAccount() async {
        let work = work { [now] in now }
        work.library = [lumen]
        work.checkHandler = { "offline" }
        await work.check()
        work.detach()
        #expect(work.library.isEmpty)
        #expect(work.checkHandler == nil)
        #expect(work.connectionProblem == nil)
    }
}
