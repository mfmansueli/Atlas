//
//  PageShotsLookTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Board 52's Look on Private diary: another template lays the set out
/// with that starter, and a new look from Claude Design is a stop where
/// the person chooses one of three; the default page's template never
/// changes.
@MainActor
@Suite("Page screenshots look")
struct PageShotsLookTests {
    typealias Test = PageShotsTestFixtures

    private func candidate(_ name: String, _ starter: TemplateStarter = .band) -> PageShotsLookCandidate {
        PageShotsLookCandidate(
            id: "look-\(name)", name: name, rationale: "Because.", template: ScreenshotTemplate.starter(starter, id: Test.app.id, title: "Lumen"),
            link: nil, source: "Claude Code", receivedAt: .now
        )
    }

    @Test func anotherTemplateLaysTheSetOutWithThatStarter() async throws {
        let studio = PageShotsStudio()
        studio.begin(Test.run(plan: Test.plan()))
        let source = try await Test.source()
        let defaultName = try #require(source.template?.name)

        studio.choose(look: .starter(.poster), for: Test.key)
        let run = try #require(studio.run(Test.key))
        let applied = source.applying(run)
        let expected = ScreenshotTemplate.starter(.poster, id: Test.app.id, title: Test.app.name, slotCount: source.slotCount)
        #expect(applied.template == expected)
        #expect(applied.drawingKey != source.drawingKey)
        #expect(source.template?.name == defaultName)

        studio.choose(look: .same, for: Test.key)
        #expect(studio.run(Test.key)?.design == nil)
        #expect(source.applying(studio.run(Test.key)).template?.name == defaultName)
    }

    @Test func aNewLookIsChosenOfThreeAndAFourthIsRefused() throws {
        let studio = PageShotsStudio()
        studio.begin(Test.run(plan: Test.plan()))
        studio.choose(look: .claudeDesign, for: Test.key)
        #expect(studio.run(Test.key)?.design?.isReady == false)
        #expect(studio.run(Test.key)?.lookTemplate(appID: Test.app.id, appName: "Lumen", slotCount: 5) == nil)

        #expect(studio.receive(look: candidate("Quiet Indigo", .cinema), for: Test.key) == nil)
        #expect(studio.run(Test.key)?.design?.chosenID == "look-Quiet Indigo")
        #expect(studio.receive(look: candidate("Paper Lock", .poster), for: Test.key) == nil)
        #expect(studio.receive(look: candidate("Night Mode", .spotlight), for: Test.key) == nil)
        let refusal = try #require(studio.receive(look: candidate("Fourth"), for: Test.key))
        #expect(refusal.contains("“Quiet Indigo”"))

        studio.pick(lookID: "look-Paper Lock", for: Test.key)
        let run = try #require(studio.run(Test.key))
        #expect(run.design?.isReady == true)
        #expect(run.lookTemplate(appID: Test.app.id, appName: "Lumen", slotCount: 5) == candidate("Paper Lock", .poster).template)

        // Sent again with the same name, it takes the place of the one before and stays chosen.
        var revised = candidate("paper lock", .editorial)
        revised.id = "look-revised"
        #expect(studio.receive(look: revised, for: Test.key) == nil)
        let after = try #require(studio.run(Test.key)?.design)
        #expect(after.candidates.count == 3)
        #expect(after.chosenID == "look-revised")
    }

    @Test func aLooksSessionThatSentNothingSaysSo() {
        let studio = PageShotsStudio()
        let id = UUID()
        studio.begin(Test.run(plan: Test.plan()))
        studio.choose(look: .claudeDesign, for: Test.key)
        studio.askedForLooks(Test.key, claudeRunID: id)
        #expect(studio.run(Test.key)?.claudeRunIDs == [id])

        studio.claudeRunEnded(Test.session(id))
        let run = studio.run(Test.key)
        #expect(run?.design?.claudeRunID == nil)
        #expect(run?.design?.problem?.contains("before it sent a look") == true)
        #expect(run?.stage == .plan)
    }

    @Test func choosingANewLookAsksClaudeCodeOnceAndStartWaitsForOne() async throws {
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
        flow.launch = { purpose, prompt in
            prompts.append(prompt)
            purposes.append(purpose)
            return UUID()
        }
        flow.stopClaude = { stopped.append($0) }
        await flow.loadSource()
        flow.studio.begin(Test.run(plan: Test.plan(), locales: ["en-US"], displays: [.iPhone]))
        #expect(flow.canStart)

        await flow.choose(look: .claudeDesign)
        #expect(prompts.count == 1)
        #expect(prompts.first?.contains("propose_page_look") == true)
        // Not the plan's purpose: the launcher would hand back the plan's session.
        #expect(purposes == [.pageLooks(pageName: "Private diary")])
        #expect(!flow.canStart)
        await flow.choose(look: .claudeDesign)
        #expect(prompts.count == 1)

        _ = flow.studio.receive(look: candidate("Quiet Indigo"), for: flow.key)
        #expect(flow.canStart)
        #expect(flow.shownSource?.template == candidate("Quiet Indigo").template)
        let session = try #require(flow.run?.design?.claudeRunID)
        flow.startAutopilot()
        #expect(stopped.contains(session))
        await flow.studio.waitUntilMade(flow.key)
        #expect(flow.run?.stage == .result)
    }
}
