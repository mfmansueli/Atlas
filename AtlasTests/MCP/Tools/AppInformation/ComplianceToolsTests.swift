//
//  ComplianceToolsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `get_compliance` and `propose_compliance_answers` on Lumen's sample
/// content: no trader status in the EU, no ICP Filing Number in China
/// mainland, and the medical device question asked. Proposals are kept in
/// the notes until the person accepts them; nothing is queued for push.
@MainActor
@Suite("Compliance tools")
struct ComplianceToolsTests {
    private let services = DebugAppInformationServices()
    private let changes = ChangeQueue()
    private let lumen = "6450000001"

    private func context() -> MCPToolContext {
        MCPToolContext(workspace: MCPTestFixtures.workspace(changes: changes, appInformation: services), clientName: "Claude Code")
    }

    private func propose(_ answers: [JSONValue], app: String = "Lumen", couldNotSee: String? = nil) async throws -> [JSONValue] {
        var arguments: [String: JSONValue] = ["appId": .string(app), "answers": .array(answers)]
        if let couldNotSee { arguments["could_not_see"] = .string(couldNotSee) }
        let outcome = try await ProposeComplianceAnswersTool().call(MCPToolArguments(arguments), in: context())
        #expect(!outcome.isError)
        return try #require(outcome.result["results"]?.arrayValue)
    }

    private var suggestions: [ComplianceSuggestion] {
        services.notes.notes(for: lumen).complianceSuggestions
    }

    // MARK: - get_compliance

    @Test func getComplianceSaysWhatEachRegulationTakes() async throws {
        let outcome = try await GetComplianceTool().call(MCPToolArguments(["appId": "Lumen"]), in: context())
        let regulations = try #require(outcome.result["regulations"]?.arrayValue)
        #expect(regulations.compactMap { $0["rule"]?.stringValue } == ComplianceRule.allCases.map(\.rawValue))

        let trader = try #require(regulations.first { $0["rule"] == "traderStatus" })
        #expect(trader["state"] == "needsAnswer")
        #expect(trader["proposable"] == ["trader", "nonTrader"])
        #expect(trader["answer"] == .null)

        let icp = try #require(regulations.first { $0["rule"] == "icpFilingNumber" })
        #expect(icp["proposable"] == ["icpNumber", "stopSelling"])

        let vietnam = try #require(regulations.first { $0["rule"] == "vietnamGameLicense" })
        #expect(vietnam["state"] == "passes")
        #expect(vietnam["proposable"] == [])
        #expect(vietnam["whyNotProposable"]?.stringValue?.isEmpty == false)

        let medical = try #require(regulations.first { $0["rule"] == "medicalDevice" })
        #expect(medical["proposable"] == ["regulated", "notRegulated"])

        #expect(outcome.result["preparedTraderDetails"]?["name"] == "Northpier Studio")
        #expect(outcome.result["summary"]?.stringValue?.hasPrefix("5 need your answer") == true)
    }

    @Test func getComplianceShowsAnOpenSuggestion() async throws {
        _ = try await propose([["rule": "medicalDevice", "answer": "notRegulated", "why": "A journal."]])
        let outcome = try await GetComplianceTool().call(MCPToolArguments(["appId": "Lumen"]), in: context())
        let medical = try #require(outcome.result["regulations"]?.arrayValue?.first { $0["rule"] == "medicalDevice" })
        #expect(medical["openSuggestion"]?["answer"] == "notRegulated")
        #expect(medical["openSuggestion"]?["by"] == "Claude Code")
    }

    /// Not sold in China mainland: still asked, with No assumed.
    @Test func outsideChinaMainlandTheAnswerIsAnAssumedNo() async throws {
        var outside = DebugAppInformationServices()
        outside.lumenCompliance = DebugAppInformationContent.complianceOutsideChina
        let context = MCPToolContext(workspace: MCPTestFixtures.workspace(changes: changes, appInformation: outside), clientName: "Claude Code")
        let outcome = try await GetComplianceTool().call(MCPToolArguments(["appId": "Lumen"]), in: context)
        let regulations = try #require(outcome.result["regulations"]?.arrayValue)
        let aiContent = try #require(regulations.first { $0["rule"] == "aiGeneratedContent" })
        #expect(aiContent["state"] == "toEnter")
        #expect(aiContent["answer"]?["answer"] == "noAI")
        #expect(aiContent["answer"]?["assumed"] == "notSoldInChinaMainland")
        #expect(aiContent["proposable"] == ["offersAI", "noAI"])
        let security = try #require(regulations.first { $0["rule"] == "securityAssessment" })
        #expect(security["answer"]?["answer"] == "noAssessment")
    }

    @Test func chinaMainlandsDeclarationsAreProposable() async throws {
        let outcome = try await GetComplianceTool().call(MCPToolArguments(["appId": "Lumen"]), in: context())
        let regulations = try #require(outcome.result["regulations"]?.arrayValue)
        let security = try #require(regulations.first { $0["rule"] == "securityAssessment" })
        #expect(security["state"] == "needsAnswer")
        #expect(security["proposable"] == ["needsAssessment", "noAssessment"])
        let aiContent = try #require(regulations.first { $0["rule"] == "aiGeneratedContent" })
        #expect(aiContent["proposable"] == ["offersAI", "noAI"])
        #expect(aiContent["answer"] == .null)
    }

    // MARK: - propose_compliance_answers

    @Test func aTraderIsKeptWithThePreparedDetailsUnderWhatItFound() async throws {
        let results = try await propose(
            [[
                "rule": "traderStatus",
                "answer": "trader",
                "traderDetails": ["address": "14 Harbour Road, Dublin 2", "name": ""],
                "why": "Sells a subscription in the EU.",
                "evidence": ["Website/imprint.html:12 — company address"],
            ]],
            couldNotSee: "Whether the phone still answers."
        )
        #expect(results.first?["status"] == "queued")
        #expect(results.first?["answer"] == "trader")
        let suggestion = try #require(suggestions.first)
        guard case let .trader(details) = suggestion.answer else {
            Issue.record("Expected a trader answer, got \(suggestion.answer)")
            return
        }
        #expect(details.name == "Northpier Studio")
        #expect(details.address == "14 Harbour Road, Dublin 2")
        #expect(suggestion.client == "Claude Code")
        #expect(suggestion.evidence.evidence == ["Website/imprint.html:12 — company address"])
        #expect(suggestion.evidence.couldNotSee == "Whether the phone still answers.")
        #expect(changes.changes(for: lumen).isEmpty)
    }

    @Test func aLaterAnswerReplacesTheEarlierOneAndTheSameOneIsUnchanged() async throws {
        _ = try await propose([["rule": "icpFilingNumber", "answer": "stopSelling"]])
        let number = DebugAppInformationContent.icpNumber
        let replaced = try await propose([["rule": "icpFilingNumber", "answer": "icpNumber", "icpNumber": .string(number)]])
        #expect(replaced.first?["status"] == "queued")
        #expect(suggestions.map(\.answer) == [.icpNumber(number)])

        let again = try await propose([["rule": "icpFilingNumber", "answer": "icpNumber", "icpNumber": .string(number)]])
        #expect(again.first?["status"] == "unchanged")
        #expect(suggestions.count == 1)
    }

    @Test func theAnswerThePersonGaveIsUnchanged() async throws {
        var notes = services.notes.notes(for: lumen)
        notes.compliance.trader = .nonTrader
        services.notes.setNotes(notes, for: lumen)
        let results = try await propose([["rule": "traderStatus", "answer": "nonTrader"]])
        #expect(results.first?["status"] == "unchanged")
        #expect(suggestions.isEmpty)
    }

    @Test func whatCannotBeTakenIsRefusedWithWhy() async throws {
        let results = try await propose([
            ["rule": "vietnamGameLicense", "answer": "declared"],
            ["rule": "exportCompliance", "answer": "exempt"],
            ["rule": "traderStatus", "answer": "regulated"],
            ["rule": "icpFilingNumber", "answer": "icpNumber", "icpNumber": "12345"],
        ])
        #expect(results.map { $0["status"] } == ["refused", "refused", "refused", "refused"])
        #expect(results[0]["reason"]?.stringValue?.contains("App Store Connect") == true)
        #expect(results[1]["reason"]?.stringValue?.contains("Unknown rule") == true)
        #expect(results[2]["reason"]?.stringValue?.contains("trader or nonTrader") == true)
        #expect(results[3]["reason"]?.stringValue?.contains(ICPFilingNumber.example) == true)
        #expect(suggestions.isEmpty)
    }

    @Test func aRegulationThatAppleDoesNotAskAboutIsRefused() async throws {
        let results = try await propose([["rule": "traderStatus", "answer": "nonTrader"]], app: "Tempo Metronome")
        #expect(results.first?["status"] == "refused")
        #expect(results.first?["reason"]?.stringValue?.hasPrefix("Nothing to answer") == true)
    }

    @Test func theToolsAreInTheToolboxAndProposingNeedsAppInformation() {
        #expect(MCPToolbox.standard.toolNames.isSuperset(of: ["get_compliance", "propose_compliance_answers"]))
        #expect(ProposeComplianceAnswersTool().definition.proposalKind == .appInformation)
        #expect(GetComplianceTool().definition.proposalKind == nil)
    }

    @Test func anAIFilingAndASecurityAnswerWaitOnTheirCards() async throws {
        let results = try await propose([
            [
                "rule": "aiGeneratedContent", "answer": "offersAI", "why": "Reflect calls Mingyu's model.",
                "aiFiling": ["kind": "largeLanguageModel", "number": " Shanghai-MingyuReflect-202603120001 ", "name": "Mingyu Reflect Model",
                             "technologyOwner": "Shanghai Mingyu Technology Co., Ltd."],
            ],
            ["rule": "securityAssessment", "answer": "noAssessment", "why": "Entries stay private."],
        ])
        #expect(results.map { $0["status"] } == ["queued", "queued"])
        let aiContent = try #require(suggestions.first { $0.rule == .aiGeneratedContent })
        guard case let .aiContent(answer) = aiContent.answer else {
            Issue.record("Expected an AI answer, got \(aiContent.answer)")
            return
        }
        #expect(answer.offersAI)
        #expect(answer.filing == DebugAppInformationContent.aiFiling)
        #expect(suggestions.first { $0.rule == .securityAssessment }?.answer == .securityAssessment(isNeeded: false))
        #expect(changes.changes.isEmpty)
    }

    @Test func aFilingKindThatIsntOneIsRefused() async throws {
        let results = try await propose([["rule": "aiGeneratedContent", "answer": "offersAI", "aiFiling": ["kind": "model"]]])
        #expect(results.first?["status"] == "refused")
        #expect(results.first?["reason"]?.stringValue == "aiFiling.kind is largeLanguageModel or algorithm.")
    }
}
#endif
