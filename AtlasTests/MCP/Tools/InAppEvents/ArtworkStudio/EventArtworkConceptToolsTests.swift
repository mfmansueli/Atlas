//
//  EventArtworkConceptToolsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `get_event_artwork_brief` and `propose_event_artwork_concept` (board
/// 47): Claude Code reads what the person asked for and sends each concept,
/// which Atlas renders, checks and shows in the sheet. Nothing is queued.
@MainActor
@Suite("Event artwork concept MCP tools", .serialized)
struct EventArtworkConceptToolsTests {
    typealias Test = EventArtworkStudioTestData
    typealias Events = InAppEventsTestData

    private let directory = EventArtworkTestFiles.directory()
    private let studio = EventArtworkStudio()
    private let changes = ChangeQueue()
    private let pages = EventArtworkRenderedPages()

    private func call(_ tool: some MCPTool, _ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        var workspace = MCPTestFixtures.workspace(changes: changes)
        workspace.services.inAppEvents = FakeInAppEventsServices(Events.events)
        let context = MCPToolContext(workspace: workspace, clientName: "Claude Code", allowedProposals: Set(MCPProposalKind.allCases))
        let base: [String: JSONValue] = ["appId": "Lumen Journal", "eventId": "winter"]
        return try await tool.call(MCPToolArguments(base.merging(arguments) { $1 }), in: context)
    }

    private func brief(_ arguments: [String: JSONValue] = [:]) async throws -> MCPToolOutcome {
        try await call(GetEventArtworkBriefTool(studio: studio, autopilot: AutopilotCenter(), loadsCard: false), arguments)
    }

    private func propose(_ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        try await call(ProposeEventArtworkConceptTool(studio: studio, directory: directory, loopFrames: 3, pages: pages), arguments)
    }

    private func render(_ kind: String, _ html: String) async throws -> MCPToolOutcome {
        try await call(RenderEventArtworkTool(directory: directory, pages: pages, studio: studio), ["kind": .string(kind), "html": .string(html)])
    }

    private func files(busy: Bool = false) throws -> [String: JSONValue] {
        let card = try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: 1920, height: 1080, busy: busy), name: "c.png", in: directory)
        let details = try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: 1080, height: 1920), name: "d.png", in: directory)
        return ["cardFileId": .string(card), "detailsFileId": .string(details)]
    }

    @Test func theToolsAreInTheToolboxAndTheInstructions() {
        #expect(MCPToolbox.standard.toolNames.isSuperset(of: ["get_event_artwork_brief", "propose_event_artwork_concept"]))
        #expect(GetEventArtworkBriefTool().definition.isReadOnly)
        #expect(ProposeEventArtworkConceptTool().definition.proposalKind == .artwork)
        #expect(MCPEndpoint.instructions.contains("get_event_artwork_brief"))
        #expect(MCPEndpoint.instructions.contains("propose_event_artwork_concept"))
        #expect(ClaudeCodeRunPurpose.eventArtworkConcepts(eventID: "winter").permissions == .eventArtwork)
    }

    @Test func withoutARunBothToolsSayHowToStart() async throws {
        let read = try await brief()
        #expect(read.result["status"] == "refused")
        #expect(read.result["reason"]?.stringValue?.contains("Make the Artwork") == true)
        let sent = try await propose(["name": "Path", "why": "Why."].merging(files()) { $1 })
        #expect(sent.result["status"] == "refused")
    }

    @Test func theBriefHasWhatThePersonAskedFor() async throws {
        var run = Test.run(style: .template)
        run.wordsInArt = true
        run.makesMotion = true
        studio.begin(run)
        let result = try await brief().result
        #expect(result["brief"] == "Snow on a path.")
        #expect(result["look"]?["style"] == "template")
        #expect(result["look"]?["templates"]?.arrayValue?.first?["id"] == "challenge")
        #expect(result["wordsInArt"] == true)
        #expect(result["motion"] == true)
        #expect(result["event"]?["name"] == "Winter Reflection Challenge")
        #expect(result["event"]?["namesByLanguage"]?["de-DE"] == "Winter-Reflexion")
        #expect(result["kinds"]?.arrayValue == ["card", "details"])
        #expect(result["rules"]?.arrayValue?.contains { $0.stringValue?.contains("{{eventName}}") == true } == true)
        #expect(result["concepts"]?["expected"] == 3)
        #expect(result["then"]?.stringValue?.hasPrefix("Render each image with render_event_artwork") == true)
        #expect(result["then"]?.stringValue?.hasSuffix("send 3 more concepts with propose_event_artwork_concept, one call each, then finish.") == true)
        #expect(result["rules"]?.arrayValue?.contains { $0.stringValue?.contains("as motionDirection says") == true } == true)
        #expect(result["motionDirection"]?["selfCheck"]?.arrayValue?.isEmpty == false)
    }

    /// Every brief carries the art direction, so the first concepts are
    /// finished illustrations of the event that were looked at before
    /// they're sent, not the app's mark on an empty sky.
    @Test func theBriefHasTheArtDirectionAndTheCheckOfEachRender() async throws {
        studio.begin(Test.run(style: .template))
        let result = try await brief().result
        let direction = try #require(result["artDirection"])
        #expect(direction == EventArtworkDirection.json)
        let check = direction["selfCheck"]?.arrayValue?.compactMap(\.stringValue) ?? []
        #expect(check.first?.contains("render_event_artwork") == true)
        #expect(check.count == 8)
        #expect(check.last?.contains("otherEvents") == true)
        #expect(direction["idea"]?.arrayValue?.contains { $0.stringValue?.contains("this event's alone") == true } == true)
        #expect(result["look"]?["how"]?.stringValue?.contains("events with the same badge share it") == true)
        #expect(direction["appStoreLayout"]?["card"]?.stringValue?.contains("lower 60%") == true)
        #expect(direction["appStoreLayout"]?["lowerPart"]?.stringValue?.contains("Never an empty band") == true)
        #expect(direction["idea"]?.arrayValue?.contains { $0.stringValue?.contains("Don't redraw the app's icon") == true } == true)
        #expect(direction["craft"]?.arrayValue?.contains { $0.stringValue?.contains("feTurbulence") == true } == true)
        #expect(result["look"]?["how"]?.stringValue?.contains("not a picture to copy") == true)
        #expect(result["rules"]?.arrayValue?.first?.stringValue?.contains("never an empty band") == true)
    }

    /// Another event of the same app already drawn: its ideas come in the
    /// brief and in each answer while concepts are still to come (runs
    /// drawn at once read their briefs before the others sent anything).
    /// On Alba two Challenge events both got a path of lights to the dawn.
    @Test func otherEventsIdeasKeepThisEventsOwn() async throws {
        studio.begin(Test.run())
        let alone = try await brief().result
        #expect(alone["otherEvents"] == nil)
        var gratitude = EventArtworkRun(
            appID: Events.app.id, eventID: Events.gratitude.id, eventName: Events.gratitude.referenceName, brief: "Thanks.", style: .template,
            locales: ["en-US"]
        )
        gratitude.step = .check
        gratitude.concepts = try [Test.concept("a", in: directory), Test.concept("b", in: directory)]
        gratitude.usedConceptID = "b"
        studio.begin(gratitude)

        let others = try #require(try await brief().result["otherEvents"])
        #expect(others["how"]?.stringValue?.contains("different ideas") == true)
        let event = try #require(others["events"]?.arrayValue?.first)
        #expect(event["event"] == "Gratitude Week")
        #expect(event["concepts"]?.arrayValue?.map { $0["name"] } == ["Concept a", "Concept b"])
        #expect(event["concepts"]?.arrayValue?.last?["used"] == true)
        #expect(event["concepts"]?.arrayValue?.first?["used"] == nil)

        let first = try await propose(["name": "Snowfall Path", "why": "Reads small."].merging(files()) { $1 }).result
        #expect(first["otherEvents"] == others)
        #expect(first["then"] == "Send the next concept (2 left), a different idea from otherEvents' too.")
        _ = try await propose(["name": "Lantern", "why": "Warm."].merging(files()) { $1 })
        let last = try await propose(["name": "Aurora", "why": "Rich."].merging(files()) { $1 }).result
        #expect(last["otherEvents"] == nil)
        #expect(last["then"] == "Done: the person chooses in Atlas. Finish without pushing anything.")
        // This event's own concepts aren't "other events" to itself.
        #expect(EventArtworkOtherEvents.json(studio.runs(for: Events.app.id), except: Events.gratitude.id)?["events"]?.arrayValue?.first?["event"]
            == "Winter Reflection 2026")
    }

    /// A read of the events that fails once (Alba's run got one 403 in the
    /// middle) is tried again instead of costing the concept.
    @Test func aFailedEventReadIsTriedOnceMore() async throws {
        let services = FakeInAppEventsServices(Events.events)
        services.error = .forbidden(detail: nil)
        services.failingReads = 1
        var workspace = MCPTestFixtures.workspace(changes: changes)
        workspace.services.inAppEvents = services
        let context = MCPToolContext(workspace: workspace, clientName: "Claude Code", allowedProposals: [])
        let app = try await workspace.app(matching: "Lumen Journal")
        let event = try await RenderEventArtworkTool.event("winter", of: app, in: context, retryAfter: .zero)
        #expect(event.id == "winter")
        #expect(services.readCount == 2)

        services.failingReads = nil
        await #expect(throws: AppStoreConnectError.self) {
            try await RenderEventArtworkTool.event("winter", of: app, in: context, retryAfter: .zero)
        }
        #expect(services.readCount == 4)
    }

    @Test func extendingTheCardMakesOnlyTheDetailsImage() async throws {
        studio.begin(Test.run(style: .extendCard))
        #expect(try await brief().result["kinds"]?.arrayValue == ["details"])
        let details = try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: 1080, height: 1920), name: "d.png", in: directory)
        let sent = try await propose(["name": "Tall Path", "why": "Continues the card.", "detailsFileId": .string(details)])
        #expect(sent.result["status"] == "received")
        #expect(studio.run(appID: Test.key.appID, eventID: Test.key.eventID)?.concepts.first?.kinds == [.details])
    }

    @Test func conceptsArriveOneByOneThenThePersonChooses() async throws {
        studio.begin(Test.run())
        let first = try await propose(["name": "Snowfall Path", "why": "Reads small.", "pick": true].merging(files()) { $1 })
        #expect(first.result["status"] == "received")
        #expect(first.result["ready"] == 1)
        #expect(first.result["then"] == "Send the next concept (2 left).")
        _ = try await propose(["name": "Lantern", "why": "Warm."].merging(files()) { $1 })
        let last = try await propose(["name": "Aurora", "why": "Rich."].merging(files(busy: true)) { $1 })
        #expect(last.result["warnings"]?.arrayValue?.isEmpty == false)
        #expect(last.result["then"] == "Done: the person chooses in Atlas. Finish without pushing anything.")
        let run = try #require(studio.run(appID: Test.key.appID, eventID: Test.key.eventID))
        #expect(run.step == .choose)
        #expect(run.concepts.map(\.name) == ["Snowfall Path", "Lantern", "Aurora"])
        #expect(run.concepts[0].isPick)
        #expect(run.concepts[2].checks.first?.isOK == false)
        #expect(changes.changes.isEmpty)
        let more = try await propose(["name": "Fourth", "why": "More."].merging(files()) { $1 })
        #expect(more.result["status"] == "refused")
    }

    @Test func aRevisionReplacesItsConcept() async throws {
        var run = try Test.run(step: .making, concepts: [Test.concept("a", isPick: true, in: directory), Test.concept("b", in: directory)])
        run.revisingID = "a"
        run.revisionRequest = "Warmer"
        run.concepts[0].pages = [.card: "<html>card</html>"]
        studio.begin(run)
        let read = try await brief()
        #expect(read.result["revision"]?["request"] == "Warmer")
        #expect(read.result["revision"]?["pages"]?["card"] == "<html>card</html>")
        #expect(read.images.count == 2)
        #expect(read.result["then"]?.stringValue?.contains("render it with render_event_artwork") == true)
        let unasked = try await propose(["name": "New", "why": "New."].merging(files()) { $1 })
        #expect(unasked.result["status"] == "refused")
        let sent = try await propose(["name": "Warmer Path", "why": "Warmer.", "replaces": "a"].merging(files()) { $1 })
        #expect(sent.result["conceptId"] == "a")
        let updated = try #require(studio.run(appID: Test.key.appID, eventID: Test.key.eventID))
        #expect(updated.step == .check)
        #expect(updated.concepts[0].name == "Warmer Path")
    }

    @Test func aRefusedRenderIsntTaken() async throws {
        studio.begin(Test.run())
        let small = try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: 800, height: 450), name: "small.png", in: directory)
        let details = try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: 1080, height: 1920), name: "d.png", in: directory)
        let sent = try await propose(["name": "Small", "why": "Small.", "cardFileId": .string(small), "detailsFileId": .string(details)])
        #expect(sent.result["status"] == "refused")
        #expect(sent.result["refusals"]?.arrayValue?.isEmpty == false)
        let missing = try await propose(["name": "Half", "why": "Half.", "detailsFileId": .string(details)])
        #expect(missing.result["reason"] == "Give the event card as cardHtml or cardFileId.")
        #expect(studio.run(appID: Test.key.appID, eventID: Test.key.eventID)?.concepts.isEmpty == true)
    }

    /// With words in the art, {{eventName}} becomes each language's name.
    @Test func wordsInTheArtRenderEachLanguage() async throws {
        var run = Test.run()
        run.wordsInArt = true
        studio.begin(run)
        let page = "<!doctype html><html><body style='margin:0;background:#1f2e5c'><p>{{eventName}}</p></body></html>"
        let sent = try await propose(["name": "Named", "why": "Named.", "cardHtml": .string(page), "detailsHtml": .string(page)])
        #expect(sent.result["status"] == "received")
        let concept = try #require(studio.run(appID: Test.key.appID, eventID: Test.key.eventID)?.concepts.first)
        #expect(Set(concept.stills.compactMap(\.locale)) == ["en-US", "de-DE"])
        #expect(concept.stills.count == 4)
        #expect(concept.pages[.card] == page)
        #expect(ProposeEventArtworkConceptTool.filled("<p>{{eventName}}</p>", eventName: "A & <B>") == "<p>A &amp; &lt;B&gt;</p>")
    }

    /// With the render check, Claude sends the files it looked at. The
    /// concept still keeps their pages, for Ask for Changes.
    @Test func aConceptSentWithItsRendersKeepsThePages() async throws {
        studio.begin(Test.run())
        let page = "<!doctype html><html><body style='margin:0;background:#1f2e5c'></body></html>"
        let card = try await render("card", page)
        #expect(card.result["then"]?.stringValue?.contains("propose_event_artwork_concept") == true)
        let details = try await render("details", page)
        let sent = try await propose([
            "name": "Night Path", "why": "Calm.", "cardFileId": card.result["fileId"] ?? "", "detailsFileId": details.result["fileId"] ?? "",
        ])
        #expect(sent.result["status"] == "received")
        let concept = try #require(studio.run(appID: Test.key.appID, eventID: Test.key.eventID)?.concepts.first)
        #expect(concept.pages[.card] == page)
        #expect(concept.pages[.details] == page)
        #expect(concept.stills.count == 2)
    }

    /// A render's file is one language's still: with the name drawn in, the
    /// page is drawn again in each language.
    @Test func aRendersFileIsDrawnInEachLanguageWhenTheNameIsInTheArt() async throws {
        var run = Test.run()
        run.wordsInArt = true
        studio.begin(run)
        let page = "<!doctype html><html><body style='margin:0;background:#1f2e5c'><p>{{eventName}}</p></body></html>"
        let card = try await render("card", page)
        let details = try await render("details", page)
        _ = try await propose(["name": "Named", "why": "Named.", "cardFileId": card.result["fileId"] ?? "", "detailsFileId": details.result["fileId"] ?? ""])
        let concept = try #require(studio.run(appID: Test.key.appID, eventID: Test.key.eventID)?.concepts.first)
        #expect(Set(concept.stills.compactMap(\.locale)) == ["en-US", "de-DE"])
        #expect(concept.stills.count == 4)
    }

    @Test func outsideARunARenderIsQueuedAsItIs() async throws {
        let card = try await render("card", "<!doctype html><html><body style='margin:0;background:#1f2e5c'></body></html>")
        #expect(card.result["then"] == "propose_event_artwork with this fileId, for every language or some")
    }

    @Test func onlyTheNewestPagesAreKept() {
        let kept = EventArtworkRenderedPages(limit: 2)
        kept.remember("one", for: "a")
        kept.remember("two", for: "b")
        kept.remember("two again", for: "b")
        kept.remember("three", for: "c")
        #expect(kept.page(for: "a") == nil)
        #expect(kept.page(for: "b") == "two again")
        #expect(kept.page(for: "c") == "three")
    }

    // MARK: - Motion

    /// A page whose glow pulses every `seconds`.
    private static func moving(_ seconds: Double) -> String {
        """
        <!doctype html><html><head><style>
        html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#1f2e5c}
        #sun{position:absolute;left:30%;top:20%;width:30%;height:40%;border-radius:50%;background:#ffd27a;
        animation:pulse \(seconds)s ease-in-out infinite}
        @keyframes pulse{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.2;transform:scale(.6)}}
        </style></head><body><div id="sun"></div></body></html>
        """
    }

    @Test func makeThemMoveSendsEachConceptBackWithItsMotion() async throws {
        var run = try Test.run(step: .making, concepts: [Test.concept("a", isPick: true, in: directory), Test.concept("b", in: directory)])
        run.makesMotion = true
        run.animatingIDs = ["a", "b"]
        for index in run.concepts.indices { run.concepts[index].pages = [.card: "<html>card</html>", .details: "<html>details</html>"] }
        studio.begin(run)
        let read = try await brief()
        #expect(read.result["addMotion"]?.arrayValue?.count == 2)
        #expect(read.result["addMotion"]?.arrayValue?.first?["pages"]?["card"] == "<html>card</html>")
        #expect(read.result["motionDirection"]?["apple"]?.arrayValue?.isEmpty == false)
        #expect(read.images.count == 2)
        #expect(read.result["then"]?.stringValue?.contains("replaces") == true)

        let unasked = try await propose(["name": "New", "why": "New.", "cardHtml": .string(Self.moving(5)), "detailsHtml": .string(Self.moving(5))])
        #expect(unasked.result["status"] == "refused")
        let page = JSONValue.string(Self.moving(5))
        let first = try await propose(["name": "Concept a", "why": "Why a.", "replaces": "a", "cardHtml": page, "detailsHtml": page])
        #expect(first.result["status"] == "received")
        #expect(first.result["then"]?.stringValue?.contains("1 left") == true)
        let midway = try #require(studio.run(appID: Test.key.appID, eventID: Test.key.eventID))
        #expect(midway.step == .making)
        #expect(midway.animatingIDs == ["b"])
        #expect(midway.concepts[0].videos.count == 2)
        // swiftformat:disable:next preferKeyPath
        #expect(midway.concepts[0].videos.allSatisfy { $0.isVideo })

        let last = try await propose(["name": "Concept b", "why": "Why b.", "replaces": "b", "cardHtml": page, "detailsHtml": page])
        #expect(last.result["then"]?.stringValue?.hasPrefix("Done") == true)
        let done = try #require(studio.run(appID: Test.key.appID, eventID: Test.key.eventID))
        #expect(done.step == .choose)
        #expect(done.animatingIDs == nil)
    }

    @Test func motionFramesShowTheLoopAndCheckIt() async throws {
        studio.begin(Test.run())
        let tool = RenderEventArtworkTool(directory: directory, pages: pages, studio: studio)
        let even = try await call(tool, ["kind": "card", "html": .string(Self.moving(5)), "motionFrames": true])
        let frames = try #require(even.result["motionFrames"])
        #expect(frames["moves"] == true)
        #expect(frames["repeatsEvenly"] == true)
        #expect(frames["notes"]?.arrayValue?.isEmpty == true)
        #expect(even.images.count == 2 + RenderEventArtworkTool.motionFrameSeconds.count)

        let uneven = try await call(tool, ["kind": "card", "html": .string(Self.moving(7)), "motionFrames": true])
        #expect(uneven.result["motionFrames"]?["repeatsEvenly"] == false)
        #expect(uneven.result["motionFrames"]?["notes"]?.arrayValue?.contains { $0.stringValue?.contains("don't repeat") == true } == true)

        let still = "<!doctype html><html><body style='margin:0;background:#1f2e5c'></body></html>"
        let none = try await call(tool, ["kind": "details", "html": .string(still), "motionFrames": true])
        #expect(none.result["motionFrames"]?["moves"] == false)
        #expect(none.result["motionFrames"]?["notes"]?.arrayValue?.first?.stringValue?.hasPrefix("Nothing visibly moves") == true)
    }
}
