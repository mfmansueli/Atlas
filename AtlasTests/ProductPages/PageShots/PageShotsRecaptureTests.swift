//
//  PageShotsRecaptureTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Board 52's “2 are captured again so the lock shows”: with Capture
/// Screens Again on, the screens Claude Code captured in the Simulator
/// stand in for the default set's in the page's set, a language without
/// its own uses the primary language's, at most three screens are
/// captured again, and turning it off forgets them.
@MainActor
@Suite("Page screenshots captured again")
struct PageShotsRecaptureTests {
    typealias Test = PageShotsTestFixtures

    private func capture(slot: Int, locale: String = "en-US", display: ScreenshotDisplayType = .iPhone, id: String = "new") -> PageShotsNewCapture {
        PageShotsNewCapture(
            slot: slot, locale: locale, displayType: display, captureID: "\(id)-\(slot)-\(locale)", pixelSize: display.portraitPixelSize,
            notes: "Locked.", receivedAt: .now
        )
    }

    @Test func aScreenCapturedAgainStandsInForTheDefaultOne() async throws {
        let studio = PageShotsStudio()
        studio.begin(Test.run(plan: Test.plan()))
        #expect(studio.receive(capture: capture(slot: 4), for: Test.key)?.contains("No recapture was asked for") == true)

        studio.setRecapture(true, for: Test.key)
        let token = try #require(studio.run(Test.key)?.recapture?.uploadToken)
        #expect(studio.run(uploadToken: token)?.key == Test.key)
        #expect(studio.receive(capture: capture(slot: 4), for: Test.key) == nil)

        let source = try await Test.source()
        let applied = source.applying(studio.run(Test.key))
        let lock = PageShotsScreen(slot: 4, captions: [:])
        let other = PageShotsScreen(slot: 0, captions: [:])
        #expect(applied.capture(of: lock, locale: "en-US", displayType: .iPhone)?.capture.id == "new-4-en-US")
        // German has none of its own: the primary language's, not localized.
        let german = try #require(applied.capture(of: lock, locale: "de-DE", displayType: .iPhone))
        #expect(german.capture.id == "new-4-en-US")
        #expect(!german.isInterfaceLocalized)
        // iPad and the other screens keep the default set's.
        let defaultLockOnIPad = source.capture(of: lock, locale: "en-US", displayType: .iPad)?.capture.id
        let defaultOther = source.capture(of: other, locale: "en-US", displayType: .iPhone)?.capture.id
        #expect(applied.capture(of: lock, locale: "en-US", displayType: .iPad)?.capture.id == defaultLockOnIPad)
        #expect(applied.capture(of: other, locale: "en-US", displayType: .iPhone)?.capture.id == defaultOther)

        studio.setRecapture(false, for: Test.key)
        #expect(studio.run(Test.key)?.recapture == nil)
        #expect(studio.run(uploadToken: token) == nil)
    }

    @Test func atMostThreeScreensAndTheSameOneIsReplaced() throws {
        let studio = PageShotsStudio()
        studio.begin(Test.run(plan: Test.plan()))
        studio.setRecapture(true, for: Test.key)
        for slot in [4, 1, 2] {
            #expect(studio.receive(capture: capture(slot: slot), for: Test.key) == nil)
        }
        let refusal = try #require(studio.receive(capture: capture(slot: 3), for: Test.key))
        #expect(refusal.contains("2, 3, and 5"))
        #expect(studio.receive(capture: capture(slot: 4, id: "again"), for: Test.key) == nil)
        #expect(studio.receive(capture: capture(slot: 4, locale: "de-DE"), for: Test.key) == nil)
        let recapture = try #require(studio.run(Test.key)?.recapture)
        #expect(recapture.slots == [1, 2, 4])
        #expect(recapture.captures.filter { $0.slot == 4 }.map(\.captureID).sorted() == ["again-4-en-US", "new-4-de-DE"])

        studio.forgetCaptures(slot: 4, for: Test.key)
        #expect(studio.run(Test.key)?.recapture?.slots == [1, 2])
    }

    @Test func aCapturesSessionThatSentNothingSaysSo() {
        let studio = PageShotsStudio()
        let id = UUID()
        studio.begin(Test.run(plan: Test.plan()))
        studio.setRecapture(true, for: Test.key)
        studio.askedForCaptures(Test.key, claudeRunID: id)
        studio.claudeRunEnded(Test.session(id))
        let recapture = studio.run(Test.key)?.recapture
        #expect(recapture?.claudeRunID == nil)
        #expect(recapture?.problem?.contains("sent no capture") == true)
        #expect(studio.run(Test.key)?.stage == .plan)
    }

    @Test func turningItOnAsksClaudeCodeAndOffStopsIt() async throws {
        let queue = ChangeQueue(changes: DebugProductPagesData.pendingChanges)
        let model = await ProductPagesTestModel.make(queue: queue)
        let page = try ProductPagesTestModel.page(model, Test.pageID)
        let flow = PageShotsFlow(
            app: Test.app, page: page, studio: PageShotsStudio(), queue: queue, screenshots: DebugScreenshotsServices(),
            languages: Test.languages, ownLocales: [], note: "Private."
        )
        var prompts: [String] = []
        var purposes: [ClaudeCodeRunPurpose] = []
        var stopped: [UUID] = []
        let id = UUID()
        flow.launch = { purpose, prompt in
            prompts.append(prompt)
            purposes.append(purpose)
            return id
        }
        flow.stopClaude = { stopped.append($0) }
        flow.studio.begin(Test.run(plan: Test.plan()))

        await flow.setRecapture(true)
        #expect(prompts.count == 1)
        #expect(prompts.first?.contains("report_page_capture") == true)
        #expect(purposes == [.pageCaptures(pageName: "Private diary")])
        #expect(prompts.first?.contains(ScreenshotDisplayType.iPhone.deviceName) == true)
        #expect(flow.run?.recapture?.claudeRunID == id)

        await flow.setRecapture(false)
        #expect(stopped == [id])
        #expect(flow.run?.recapture == nil)
    }

    @Test func theLooksAndCapturesSessionsEndWithAtlas() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "PageShotsRelaunch-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let before = PageShotsStudio(directory: directory)
        before.begin(Test.run(plan: Test.plan(), claudeRunID: UUID()))
        before.choose(look: .claudeDesign, for: Test.key)
        before.askedForLooks(Test.key, claudeRunID: UUID())
        before.setRecapture(true, for: Test.key)
        before.askedForCaptures(Test.key, claudeRunID: UUID())

        let after = try #require(PageShotsStudio(directory: directory).run(Test.key))
        #expect(after.claudeRunIDs.isEmpty)
        #expect(after.look == .claudeDesign)
        #expect(after.recapture?.uploadToken == before.run(Test.key)?.recapture?.uploadToken)
    }
}
