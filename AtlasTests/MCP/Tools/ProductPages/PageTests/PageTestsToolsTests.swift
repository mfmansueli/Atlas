//
//  PageTestsToolsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `get_page_tests` and `propose_page_test` against fake App Store
/// Connect: tests and their treatments read, results said to be missing,
/// what can be tested now, and proposals that wait in Review & Push (a
/// draft's deletion as a change), refused while another test runs.
/// Nothing is pushed.
@MainActor
@Suite("Page test tools")
struct PageTestsToolsTests {
    private typealias Fixtures = ProductPageTestProposalFixtures

    @MainActor
    private struct Setup {
        let fixtures: MCPAutopilotFixtures
        let provider: FakePageTestsProvider

        var getTool: GetPageTestsTool {
            var tool = GetPageTestsTool()
            tool.provider = { [provider] _ in provider }
            return tool
        }

        var proposeTool: ProposePageTestTool {
            var tool = ProposePageTestTool()
            tool.provider = { [provider] _ in provider }
            tool.now = { Fixtures.now }
            return tool
        }

        func get(_ arguments: [String: JSONValue] = [:]) async throws -> JSONValue {
            try await fixtures.call(getTool, arguments).result
        }

        func propose(_ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
            try await fixtures.call(proposeTool, arguments)
        }

        /// The extras as saved now.
        func savedExtras() async throws -> ScreenshotExtras? {
            let app = try await fixtures.workspace.app(matching: MCPAutopilotFixtures.appID)
            return try await fixtures.services.loadDocument(for: app, primaryLocale: .englishUS).extras
        }
    }

    private func setup(
        extras: ScreenshotExtras? = Fixtures.extras(), script: FakeProductPageTesting.Script = .init(), files: [AssetLibraryFile] = Fixtures.library,
        run: AutopilotRun? = nil
    ) -> Setup {
        let fixtures = MCPAutopilotFixtures(run)
        let made = extras
        fixtures.services.documentChange = { $0.extras = made }
        return Setup(fixtures: fixtures, provider: FakePageTestsProvider(script, files: files))
    }

    private let header: [String: JSONValue] = [
        "placement": "header", "reason": "Search visitors leave the page quickly.",
        "evidence": [["kind": "analytics", "ref": "page views to downloads 2.1%"]],
    ]

    // MARK: - get_page_tests

    @Test func noTestsAndWhatCanBeTestedNow() async throws {
        let result = try await setup().get()
        #expect(result["tests"]?.arrayValue?.isEmpty == true)
        #expect(result["noTests"]?.stringValue?.contains("has no Product Page Optimization tests") == true)
        #expect(result["canProposeNow"] == true)
        #expect(result["inProgress"] == .null)
        #expect(result["resultsNote"]?.stringValue?.contains("doesn’t give a test’s results") == true)
        #expect(result["rules"]?.stringValue?.contains("one test at a time") == true)
        let testable = try #require(result["testable"]?.arrayValue)
        #expect(testable.compactMap { $0["placement"]?.stringValue } == ["header", "searchResults"])
        let header = testable[0]
        #expect(header["artwork"]?["languages"]?.arrayValue?.compactMap(\.stringValue) == ["en-US", "de-DE", "fr-FR"])
        #expect(header["variant"]?["change"] == "A calm morning page instead of the editor")
        #expect(header["variant"]?["errors"]?.arrayValue?.isEmpty == true)
        #expect(header["library"]?.arrayValue?.compactMap { $0["assetId"]?.stringValue } == ["lib-en", "lib-de"])
        #expect(header["library"]?.arrayValue?.first?["locale"] == "en-US", "The language its name carries")
        let search = testable[1]
        #expect(search["variant"] == .null)
        #expect(search["variantBlockedBecause"] == "There’s no search results variant yet.")
        #expect(search["askForVariant"]?.stringValue?.contains("no finished Autopilot run") == true)
        #expect(result["proposals"]?.arrayValue?.isEmpty == true)
    }

    @Test func pageTestsComeWithTheirTreatmentsWhenTheyArentOver() async throws {
        let placement = AssetLibraryPlacement(
            id: "p-1", placementType: ProductPageTestPlacement.header.placementType, placementGroup: "G", state: "APPROVED",
            asset: AssetLibraryAsset(id: "img-1", media: .image)
        )
        let script = FakeProductPageTesting.Script(
            tests: [Fixtures.running, Fixtures.over],
            treatments: ["exp-run": [ProductPageTreatment(id: "tr-1", name: "Outcome")]],
            treatmentLocalizations: ["tr-1": [ProductPageTreatmentLocalization(id: "trl-de", locale: "de-DE", placements: [placement])]]
        )
        let setup = setup(script: script)
        let result = try await setup.get()
        let tests = try #require(result["tests"]?.arrayValue)
        #expect(tests.count == 2)
        let running = tests[0]
        #expect(running["testId"] == "exp-run")
        #expect(running["stateTitle"] == "running")
        #expect(running["isOver"] == false)
        #expect(running["trafficProportion"] == 50)
        #expect(running["results"] == .null)
        let language = running["treatments"]?.arrayValue?.first?["languages"]?.arrayValue?.first
        #expect(language?["locale"] == "de-DE")
        #expect(language?["placements"]?.arrayValue?.first?["placement"] == "header")
        #expect(language?["placements"]?.arrayValue?.first?["assetId"] == "img-1")
        #expect(tests[1]["treatments"]?.stringValue?.contains("pass testId") == true, "A finished test's treatments aren't read")
        #expect(!setup.provider.tester.log.contains("treatments exp-old"))
        #expect(result["inProgress"]?["testId"] == "exp-run")
        #expect(result["canProposeNow"] == false)

        let one = try await setup.get(["testId": "exp-old"])
        #expect(one["tests"]?.arrayValue?[1]["treatments"]?.arrayValue != nil)
        await #expect(throws: MCPToolError.self) { try await setup.get(["testId": "exp-none"]) }
    }

    @Test func pageTestsThatCantBeReadSaySo() async throws {
        let setup = setup(script: .init(listFails: true))
        await #expect(throws: MCPToolError.self) { try await setup.get() }
    }

    // MARK: - propose_page_test

    @Test func aProposedTestWaitsForThePerson() async throws {
        let setup = setup()
        let outcome = try await setup.propose(header.merging(["trafficProportion": 30]) { $1 })
        #expect(!outcome.isError)
        let result = outcome.result
        #expect(result["status"] == "queued")
        let id = try #require(result["proposalId"]?.stringValue)
        #expect(result["proposal"]?["trafficProportion"] == 30)
        #expect(result["proposal"]?["treatment"] == "variant")
        #expect(result["proposal"]?["evidence"]?.arrayValue?.first == "analytics: page views to downloads 2.1%")
        #expect(result["next"]?.stringValue?.contains("waits in Review & Push") == true)
        #expect(result["notes"]?.arrayValue?.isEmpty == false, "The current header still waits")
        // Nothing reached App Store Connect beyond reading the tests.
        #expect(setup.provider.tester.log == ["tests \(MCPAutopilotFixtures.appID)"])

        let saved = try #require(try await setup.savedExtras())
        #expect(saved.openTestProposals.map(\.id) == [id])
        #expect(saved.openTestProposals.first?.client == "Claude Code")

        let again = try await setup.propose(header)
        #expect(again.result["replaced"] == .string(id))
        let listed = try await setup.get()
        #expect(listed["proposals"]?.arrayValue?.count == 1)
    }

    @Test func anotherTestInTheWayRefusesIt() async throws {
        let setup = setup(script: .init(tests: [Fixtures.running]))
        let result = try await setup.propose(header).result
        #expect(result["status"] == "refused")
        #expect(result["code"] == "test_in_progress")
        #expect(result["reason"]?.stringValue?.contains("one test at a time") == true)
        #expect(try await setup.savedExtras()?.testProposals == nil)
    }

    @Test func aDraftInTheWayCanBeProposedForDeletion() async throws {
        let setup = setup(script: .init(tests: [Fixtures.draft]))
        let refused = try await setup.propose(header).result
        #expect(refused["reason"]?.stringValue?.contains("action: deleteDraft, testId: exp-draft") == true)

        let deletion = try await setup.propose(["action": "deleteDraft", "testId": "exp-draft", "reason": "It blocks the header test."]).result
        #expect(deletion["status"] == "queued")
        #expect(deletion["changeId"] == "pagetest.delete.exp-draft")
        let change = try #require(setup.fixtures.workspace.changes.changes(for: MCPAutopilotFixtures.appID).first { $0.id == "pagetest.delete.exp-draft" })
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(change.requests.first?.method == .delete)
        #expect(!setup.provider.tester.log.contains("delete exp-draft"), "Only the person's push deletes it")

        let result = try await setup.propose(header).result
        #expect(result["status"] == "queued")
        #expect(result["notes"]?.arrayValue?.first?.stringValue?.contains("Deleting the draft “Icons” waits") == true)
        let listed = try await setup.get()
        #expect(listed["inProgress"]?["deletionQueued"] == true)
        #expect(listed["canProposeNow"] == true)
    }

    @Test func onlyADraftIsProposedForDeletion() async throws {
        let setup = setup(script: .init(tests: [Fixtures.running]))
        let result = try await setup.propose(["action": "deleteDraft", "testId": "exp-run", "reason": "Stop it."]).result
        #expect(result["code"] == "not_a_draft")
        let unknown = try await setup.propose(["action": "deleteDraft", "testId": "exp-x", "reason": "Gone."]).result
        #expect(unknown["code"] == "unknown_test")
        #expect(setup.fixtures.workspace.changes.changes(for: MCPAutopilotFixtures.appID).isEmpty)
    }

    @Test func withoutAVariantAtlasAsksTheRunForOne() async throws {
        let setup = setup(extras: Fixtures.extras(variant: nil), run: StudioDebugExtras.run(.ready))
        let result = try await setup.propose(header).result
        #expect(result["status"] == "queued")
        #expect(result["variant"] == "asked")
        #expect(result["next"]?.stringValue?.contains("propose_artwork_variant") == true)
        let request = try #require(setup.fixtures.run?.variantRequest)
        #expect(request.role == .header)
        #expect(request.kind == .header)
    }

    @Test func libraryImagesCanBeTheTreatment() async throws {
        let setup = setup(extras: nil)
        var arguments = header
        arguments["treatment"] = "library"
        arguments["assets"] = [["locale": "en-US", "assetId": "lib-en"], ["locale": "de", "assetId": "lib-de"]]
        let result = try await setup.propose(arguments).result
        #expect(result["status"] == "queued")
        #expect(result["proposal"]?["locales"]?.arrayValue?.compactMap(\.stringValue) == ["en-US", "de-DE"])
        #expect(result["proposal"]?["assets"]?.arrayValue?.compactMap { $0["assetId"]?.stringValue } == ["lib-en", "lib-de"])
        #expect(try await setup.savedExtras()?.openTestProposals.count == 1, "Kept even though Autopilot made no artwork")

        arguments["assets"] = [["locale": "en-US", "assetId": "lib-small"]]
        #expect(try await setup.propose(arguments).result["code"] == "wrong_size")
    }

    @Test func anAssistantWithdrawsOnlyItsOwnOpenProposal() async throws {
        let setup = setup()
        let id = try #require(try await setup.propose(header).result["proposalId"]?.stringValue)
        let withdrawn = try await setup.propose(["action": "withdraw", "proposalId": .string(id)]).result
        #expect(withdrawn["status"] == "withdrawn")
        #expect(try await setup.savedExtras()?.testProposal(id: id)?.status == .withdrawn)
        #expect(try await setup.propose(["action": "withdraw", "proposalId": .string(id)]).result["code"] == "decided")
        #expect(try await setup.propose(["action": "withdraw", "proposalId": "pt-none"]).result["code"] == "unknown_proposal")
    }

    @Test func badArgumentsAreErrors() async throws {
        let setup = setup()
        await #expect(throws: MCPToolError.self) { try await setup.propose(["reason": "x"]) }
        await #expect(throws: MCPToolError.self) { try await setup.propose(["placement": "icon", "reason": "x"]) }
        await #expect(throws: MCPToolError.self) { try await setup.propose(["action": "stop"]) }
        #expect(try await setup.propose(["placement": "search", "reason": "x"]).result["code"] == "no_variant", "search is searchResults")
    }

    // MARK: - Where assistants find them

    @Test func theToolsAreListedAndExplained() {
        #expect(MCPToolbox.standard.tool(named: "get_page_tests") != nil)
        #expect(MCPToolbox.standard.tool(named: "propose_page_test")?.definition.proposalKind == .artwork)
        #expect(MCPEndpoint.instructions.contains("read get_page_tests"))
        #expect(MCPEndpoint.instructions.contains("propose_page_test"))
    }
}
#endif
