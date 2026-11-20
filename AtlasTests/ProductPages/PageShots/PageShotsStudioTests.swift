//
//  PageShotsStudioTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A page's screenshot run (board 52): the plan waits at Plan once every
/// language has its captions or Claude Code's session ends; Autopilot lays
/// out every chosen language on every chosen device, the primary first;
/// Ask for Changes lays the set out again when the new plan arrives, and
/// says so calmly when none comes. Runs survive a relaunch.
@MainActor
@Suite("Page screenshots studio")
struct PageShotsStudioTests {
    typealias Test = PageShotsTestFixtures

    @Test func aFirstPlanWaitsWhileClaudeStillWritesLanguages() async throws {
        let studio = PageShotsStudio()
        let source = try await Test.source()
        studio.begin(Test.run(stage: .planning, claudeRunID: UUID()))

        studio.receive(Test.plan(locales: ["en-US"]), for: Test.key, source: source)
        #expect(studio.run(Test.key)?.stage == .planning)
        #expect(studio.run(Test.key)?.locales == ["en-US"])

        var everyLanguage = Test.plan()
        for index in everyLanguage.screens.indices {
            everyLanguage.screens[index].captions["ja"] = PageShotsCaption(headline: "日記 \(index + 1)")
        }
        studio.receive(everyLanguage, for: Test.key, source: source)
        let run = try #require(studio.run(Test.key))
        #expect(run.stage == .plan)
        #expect(run.locales == ["en-US", "ar-SA"])
        #expect(run.images.isEmpty)
    }

    @Test func whenClaudeStopsThePlanSaysWhatsMissing() async throws {
        let studio = PageShotsStudio()
        let id = UUID()
        studio.begin(Test.run(stage: .planning, claudeRunID: id))
        studio.claudeRunEnded(Test.session(UUID()))
        #expect(studio.run(Test.key)?.stage == .planning)

        studio.claudeRunEnded(Test.session(id))
        #expect(studio.run(Test.key)?.stage == .plan)
        #expect(studio.run(Test.key)?.problem == "Claude Code stopped before it sent a plan. Ask it again.")

        let second = UUID()
        studio.asked(Test.key, claudeRunID: second, change: nil)
        let source = try await Test.source()
        studio.receive(Test.plan(locales: ["en-US", "de-DE"]), for: Test.key, source: source)
        studio.claudeRunEnded(Test.session(second))
        let run = try #require(studio.run(Test.key))
        #expect(run.stage == .plan)
        #expect(run.locales == ["en-US"])
        #expect(run.problem == "2 languages have no captions yet, so they keep the default page’s screenshots.")
    }

    @Test func autopilotLaysOutEveryLanguageOnEveryDevicePrimaryFirst() async throws {
        let studio = PageShotsStudio()
        studio.begin(Test.run(plan: Test.plan(count: 3), locales: ["en-US", "de-DE"], displays: [.iPhone, .iPad]))
        try await studio.make(Test.key, source: Test.source())
        #expect(studio.run(Test.key)?.stage == .making)
        await studio.waitUntilMade(Test.key)

        let run = try #require(studio.run(Test.key))
        #expect(run.stage == .result)
        #expect(run.problem == nil)
        #expect(run.images.count == 12)
        #expect(run.expectedCount == 12)
        #expect(run.images.prefix(3).allSatisfy { $0.locale == "en-US" && $0.displayType == .iPhone })
        #expect(run.images(locale: "de-DE", displayType: .iPad).map(\.position) == [0, 1, 2])
        #expect(Set(run.images.map(\.fileName)).count == 12)
        for image in run.images {
            let data = try Data(contentsOf: studio.url(of: image, in: run))
            #expect(data.count == image.fileSize)
            #expect(ScreenshotPNG.checksum(data) == image.checksum)
            #expect(image.fits)
        }
        #expect(run.useLocales == ["en-US", "de-DE"])
        #expect(run.usedImages.count == 12)
    }

    @Test func stopGoesBackToPlanWithThePlanAsItWas() async throws {
        let studio = PageShotsStudio()
        studio.holdAfter = 1
        studio.begin(Test.run(plan: Test.plan(count: 3)))
        try await studio.make(Test.key, source: Test.source())
        await studio.waitUntilMade(Test.key)
        #expect(studio.run(Test.key)?.stage == .making)
        #expect(studio.run(Test.key)?.images.count == 1)

        studio.stopMaking(Test.key)
        #expect(studio.run(Test.key)?.stage == .plan)
        #expect(studio.run(Test.key)?.plan?.screens.count == 3)
    }

    @Test func askForChangesLaysTheSetOutAgainWhenTheNewPlanArrives() async throws {
        let studio = PageShotsStudio()
        let source = try await Test.source()
        studio.begin(Test.run(plan: Test.plan(count: 2), locales: ["en-US", "de-DE"]))
        studio.make(Test.key, source: source)
        await studio.waitUntilMade(Test.key)
        let before = try #require(studio.run(Test.key)?.images.map(\.checksum))

        let id = UUID()
        studio.asked(Test.key, claudeRunID: id, change: "Open with search")
        #expect(studio.run(Test.key)?.stage == .revising)
        #expect(studio.run(Test.key)?.changeRequest == "Open with search")

        var plan = Test.plan(locales: ["en-US", "de-DE"], count: 2)
        plan.screens.swapAt(0, 1)
        studio.receive(plan, for: Test.key, source: source)
        #expect(studio.run(Test.key)?.stage == .making)
        await studio.waitUntilMade(Test.key)

        let run = try #require(studio.run(Test.key))
        #expect(run.stage == .result)
        #expect(run.changeRequest == nil)
        #expect(run.images.count == 4)
        #expect(run.images.map(\.checksum) != before)
        studio.claudeRunEnded(Test.session(id))
        #expect(studio.run(Test.key)?.stage == .result)
    }

    @Test func aChangeThatNeverCameKeepsTheSet() async throws {
        let studio = PageShotsStudio()
        studio.begin(Test.run(plan: Test.plan(count: 2, madeAt: .distantPast)))
        try await studio.make(Test.key, source: Test.source())
        await studio.waitUntilMade(Test.key)
        let id = UUID()
        studio.asked(Test.key, claudeRunID: id, change: "Shorter captions")
        studio.claudeRunEnded(Test.session(id))

        let run = try #require(studio.run(Test.key))
        #expect(run.stage == .result)
        #expect(run.images.count == 2)
        #expect(run.problem == "Claude Code stopped before it changed the set. The set is as it was.")
    }

    @Test func runsComeBackAfterARelaunchAndWhatWasUnderWayStartsOver() {
        let directory = FileManager.default.temporaryDirectory.appending(path: "PageShotsStudioTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let studio = PageShotsStudio(directory: directory)
        studio.begin(Test.run(stage: .making, plan: Test.plan(), claudeRunID: UUID()))
        var other = Test.run(stage: .planning, claudeRunID: UUID())
        other.id = "run-2"
        other.pageName = "Mood tracking"
        studio.begin(other)

        let relaunched = PageShotsStudio(directory: directory)
        #expect(relaunched.runs.count == 2)
        #expect(relaunched.run(Test.key)?.stage == .plan)
        #expect(relaunched.run(Test.key)?.claudeRunID == nil)
        #expect(relaunched.run(appID: Test.app.id, pageName: "mood tracking")?.stage == .plan)
        #expect(relaunched.run(Test.key)?.plan?.screens == Test.plan().screens)
    }

    @Test func aRenamedPageTakesItsRunAlongAndCancelRemovesIt() {
        let studio = PageShotsStudio()
        studio.begin(Test.run())
        studio.presentedKey = Test.key
        studio.rename(Test.key, to: "Locked diary")
        #expect(studio.run(Test.key) == nil)
        let renamed = PageShotsRun.Key(appID: Test.app.id, pageName: "Locked diary")
        #expect(studio.run(renamed)?.pageName == "Locked diary")
        studio.remove(renamed)
        #expect(studio.runs.isEmpty)
    }
}
