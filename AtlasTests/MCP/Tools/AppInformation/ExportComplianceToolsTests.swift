//
//  ExportComplianceToolsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `get_export_compliance` and `propose_export_compliance` on Lumen's
/// sample content: build 42 attached to 1.4 says it uses no non-exempt
/// encryption, and Claude Code's earlier answers (exempt) are kept in the
/// notes. What App Store Connect takes is queued in Review & Push as the
/// assistant's; the answers and evidence go to the page.
@MainActor
@Suite("Export compliance tools")
struct ExportComplianceToolsTests {
    private let services = DebugAppInformationServices()
    private let changes = ChangeQueue()
    private let store = FieldSuggestionStore()
    private let lumen = DebugFixtures.AppID.lumen

    private func context(client: String = "Claude Code") -> MCPToolContext {
        var workspace = MCPTestFixtures.workspace(changes: changes, appInformation: services)
        workspace.suggestions = store
        return MCPToolContext(workspace: workspace, clientName: client)
    }

    private func propose(_ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        var arguments = arguments
        arguments["appId"] = "Lumen"
        let outcome = try await ProposeExportComplianceTool().call(MCPToolArguments(arguments), in: context())
        #expect(!outcome.isError)
        return outcome
    }

    private var builder: AppInformationChangeBuilder {
        let content = DebugAppInformationContent.lumen(versionID: nil)
        return AppInformationChangeBuilder(appID: lumen, ids: content.ids, versionString: content.version?.versionString)
    }

    private static let nonExempt: [String: JSONValue] = [
        "usesEncryption": true,
        "exempt": false,
        "containsProprietaryCryptography": false,
        "containsThirdPartyCryptography": true,
        "availableOnFrenchStore": true,
        "appDescription": "End-to-end encrypted sync with libsodium.",
        "why": "Sync seals entries with libsodium before upload.",
        "evidence": ["Package.resolved:14 — swift-sodium", "Sync/Sealer.swift:22 — crypto_box_seal"],
    ]

    // MARK: - get_export_compliance

    @Test func getExportComplianceReadsTheBuildAndTheAnswers() async throws {
        let outcome = try await GetExportComplianceTool().call(MCPToolArguments(["appId": "Lumen"]), in: context())
        let result = outcome.result
        #expect(result["build"]?["number"] == "42")
        #expect(result["build"]?["usesNonExemptEncryption"] == false)
        #expect(result["answers"]?["usesEncryption"] == true)
        #expect(result["answers"]?["exempt"] == true)
        #expect(result["answeredBy"] == "Claude Code")
        #expect(result["status"] == "Exempt")
        #expect(result["declarations"] == [])
        #expect(result["queued"]?["encryption"] == .null)
        #expect(result["openSuggestion"]?["by"] == "Claude Code")
        #expect(result["note"]?.stringValue?.contains("ITSAppUsesNonExemptEncryption") == true)
        #expect(GetExportComplianceTool().definition.proposalKind == nil)
    }

    // MARK: - propose_export_compliance

    @Test func exemptAnswersTheBuildAlreadyHasAreKeptWithoutAChange() async throws {
        let outcome = try await propose([
            "usesEncryption": true, "exempt": true, "why": "Only HTTPS through URLSession.",
            "evidence": ["Lumen/Info.plist:40 — no ITSAppUsesNonExemptEncryption"],
        ])
        #expect(outcome.result["status"] == "kept")
        #expect(outcome.result["usesNonExemptEncryption"] == false)
        #expect(changes.changes(for: lumen).isEmpty)
        let notes = services.notes.notes(for: lumen)
        #expect(notes.exportAnswers == ExportComplianceAnswers(answers: [.usesEncryption: true, .isExempt: true]))
        #expect(notes.exportEvidence?.why == "Only HTTPS through URLSession.")
        #expect(notes.exportEvidence?.summary == "Uses encryption: Yes · exempt: Yes")
    }

    @Test func theSameAnswersAreUnchanged() async throws {
        let outcome = try await propose([
            "usesEncryption": true, "exempt": true, "containsProprietaryCryptography": false,
            "containsThirdPartyCryptography": false, "availableOnFrenchStore": true,
        ])
        #expect(outcome.result["status"] == "unchanged")
        #expect(changes.changes(for: lumen).isEmpty)
    }

    @Test func encryptionThatIsntExemptQueuesTheBuildAndADeclaration() async throws {
        let outcome = try await propose(Self.nonExempt)
        #expect(outcome.result["status"] == "queued")
        #expect(outcome.result["usesNonExemptEncryption"] == true)
        #expect(outcome.result["declaration"]?["action"] == "create")
        #expect(outcome.result["declaration"]?["linksBuild"] == true)
        #expect(outcome.result["changeIds"] == [.string(builder.encryptionChangeID), .string(builder.declarationChangeID)])

        let encryption = try #require(changes.change(id: builder.encryptionChangeID))
        #expect(encryption.source == .assistant(client: "Claude Code"))
        #expect(encryption.requests.map(\.path) == ["/v1/builds/\(DebugAppInformationContent.buildID)"])
        #expect(AppInformationTestSupport.attributes(encryption.requests.first)["usesNonExemptEncryption"] as? Bool == true)

        let declaration = try #require(changes.change(id: builder.declarationChangeID))
        #expect(declaration.dependsOn == builder.encryptionChangeID)
        #expect(declaration.requests.map(\.method) == [.post, .patch])
        #expect(declaration.requests.map(\.path) == ["/v1/appEncryptionDeclarations", "/v1/builds/\(DebugAppInformationContent.buildID)"])
        #expect(AppInformationTestSupport.attributes(declaration.requests.first)["containsThirdPartyCryptography"] as? Bool == true)
        #expect(declaration.creation?.fields.first?.newValue == "End-to-end encrypted sync with libsodium.")
        #expect(services.notes.notes(for: lumen).exportEvidence?.evidence.count == 2)
    }

    @Test func goingBackToExemptWithdrawsTheAssistantsChanges() async throws {
        _ = try await propose(Self.nonExempt)
        let outcome = try await propose(["usesEncryption": false])
        #expect(outcome.result["status"] == "kept")
        #expect(changes.change(id: builder.encryptionChangeID) == nil)
        #expect(changes.change(id: builder.declarationChangeID) == nil)
    }

    @Test func whatsMissingIsRefusedWithWhy() async throws {
        let noExempt = try await propose(["usesEncryption": true])
        #expect(noExempt.result["status"] == "refused")
        #expect(noExempt.result["reason"]?.stringValue?.contains("exempt true or false") == true)

        let noQuestions = try await propose(["usesEncryption": true, "exempt": false])
        #expect(noQuestions.result["reason"]?.stringValue?.contains("containsProprietaryCryptography") == true)

        var noDescription = Self.nonExempt
        noDescription["appDescription"] = nil
        let refused = try await propose(noDescription)
        #expect(refused.result["status"] == "refused")
        #expect(refused.result["reason"]?.stringValue?.contains("appDescription") == true)

        var unknown = Self.nonExempt
        unknown["declarationId"] = "decl-9"
        let unknownDeclaration = try await propose(unknown)
        #expect(unknownDeclaration.result["reason"]?.stringValue?.contains("It has none.") == true)
        #expect(changes.changes(for: lumen).isEmpty)
    }

    @Test func thePersonsOwnQueuedAnswerIsLeftToThem() async throws {
        let export = DebugAppInformationContent.lumen(versionID: nil).export
        let answers = ExportComplianceAnswers(answers: [.usesEncryption: true, .isExempt: false])
        try changes.upsert(#require(builder.encryptionChange(export, to: answers)))
        let outcome = try await propose(["usesEncryption": false])
        #expect(outcome.result["status"] == "refused")
        #expect(changes.change(id: builder.encryptionChangeID)?.source == .you)
    }

    @Test func aRunCountsTheAnswer() async throws {
        let run = store.startRun(appID: lumen, client: "Claude Code", plan: [MCPComplianceRunTarget.encryption, .appInformation(.copyright)])
        _ = try await propose(["usesEncryption": false, "run": .string(run.id)])
        #expect(store.run?.arrived == [MCPComplianceRunTarget.encryption])

        store.stopRun()
        let stopped = try await propose(["usesEncryption": true, "exempt": true, "run": .string(run.id)])
        #expect(stopped.result["status"] == "refused")
        #expect(stopped.result["code"] == "run_stopped")
    }

    @Test func theToolsAreInTheToolboxAndProposingNeedsAppInformation() {
        #expect(MCPToolbox.standard.toolNames.isSuperset(of: ["get_export_compliance", "propose_export_compliance"]))
        #expect(ProposeExportComplianceTool().definition.proposalKind == .appInformation)
    }
}
#endif
