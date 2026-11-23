//
//  ReportEncryptionKeyToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `report_encryption_key` and `get_export_compliance`'s infoPlistKey on
/// Lumen's sample: build 42 says exempt, and Claude Code's exempt answers
/// wait for Confirm until a test confirms them. Reports go to their own
/// store; a value that contradicts the settled answer is refused.
@MainActor
@Suite("Encryption key tools")
struct ReportEncryptionKeyToolTests {
    private let services = DebugAppInformationServices()
    private let changes = ChangeQueue()
    private let keys = EncryptionKeyStore()
    private let projects = EncryptionKeyProjectCenter()
    private let lumen = DebugFixtures.AppID.lumen
    private static let date = Date(timeIntervalSince1970: 1_795_000_000)

    private func context(_ appInformation: DebugAppInformationServices? = nil) -> MCPToolContext {
        MCPToolContext(workspace: MCPTestFixtures.workspace(changes: changes, appInformation: appInformation ?? services), clientName: "Claude Code")
    }

    private func report(_ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        var arguments = arguments
        arguments["appId"] = "Lumen"
        let date = Self.date
        let tool = ReportEncryptionKeyTool(store: keys, now: { date })
        let outcome = try await tool.call(MCPToolArguments(arguments), in: context())
        #expect(!outcome.isError)
        return outcome
    }

    private func read(_ appInformation: DebugAppInformationServices? = nil) async throws -> JSONValue {
        try await GetExportComplianceTool(keys: keys, projects: projects).call(MCPToolArguments(["appId": "Lumen"]), in: context(appInformation)).result
    }

    private func confirm() {
        var notes = services.notes.notes(for: lumen)
        notes.exportEvidence = nil
        services.notes.setNotes(notes, for: lumen)
    }

    private static let added: [String: JSONValue] = [
        "status": "added", "value": "NO", "commit": "4f2a9c1",
        "where": [["file": "Lumen.xcodeproj/project.pbxproj", "buildSetting": "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption", "target": "Lumen",
                   "configurations": ["Debug", "Release"]]],
    ]

    @Test func addedIsKeptAndShownAsReported() async throws {
        confirm()
        let outcome = try await report(Self.added)
        #expect(outcome.result["status"] == "saved")
        #expect(outcome.result["shows"] == "Added in project.pbxproj (Lumen) · future builds answer it")
        #expect(outcome.result["warning"] == nil)
        let saved = try #require(keys.report(for: lumen))
        #expect(saved.status == .added)
        #expect(saved.places.first?.configurations == ["Debug", "Release"])
        #expect(saved.client == "Claude Code")
        #expect(saved.commit == "4f2a9c1")

        let key = try #require(try await read()["infoPlistKey"])
        #expect(key["state"] == "reported")
        #expect(key["present"] == true)
        #expect(key["value"] == "NO")
        #expect(key["report"]?["where"]?.arrayValue?.first?["target"] == "Lumen")
        #expect(key["next"]?.stringValue?.contains("Nothing to do") == true)
    }

    @Test func aValueThatContradictsTheSettledAnswerIsRefused() async throws {
        confirm()
        var yes = Self.added
        yes["value"] = "YES"
        yes["complianceCode"] = "a1b2c3"
        let outcome = try await report(yes)
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["expected"] == "NO")
        #expect(outcome.result["reason"]?.stringValue?.contains("so the key is NO, not YES") == true)
        #expect(keys.report(for: lumen) == nil)
    }

    @Test func anUnsettledAnswerKeepsTheReportWithAWarning() async throws {
        let outcome = try await report(Self.added)
        #expect(outcome.result["status"] == "saved")
        #expect(outcome.result["warning"]?.stringValue?.contains("Confirm or reject Claude Code’s answers first") == true)
    }

    @Test func whatsMissingIsRefusedWithWhy() async throws {
        let noReason = try await report(["status": "couldNotAdd"])
        #expect(noReason.result["reason"]?.stringValue?.contains("reason") == true)
        let noWhere = try await report(["status": "added", "value": "NO"])
        #expect(noWhere.result["reason"]?.stringValue?.contains("where") == true)
        let noCode = try await report(["status": "added", "value": "YES", "where": Self.added["where"] ?? []])
        #expect(noCode.result["reason"]?.stringValue?.contains("complianceCode") == true)
        let noLine = try await report(["status": "alreadyThere", "value": "NO", "where": [["file": "Lumen/Info.plist", "target": "Lumen"]]])
        #expect(noLine.result["reason"]?.stringValue?.contains("line") == true)
        let badStatus = try await report(["status": "done"])
        #expect(badStatus.result["status"] == "refused")
        #expect(keys.report(for: lumen) == nil)
    }

    @Test func couldNotAddIsKeptWithItsReason() async throws {
        let outcome = try await report(["status": "couldNotAdd", "reason": "No target builds dev.example.lumen."])
        #expect(outcome.result["shows"] == "Claude Code couldn’t add it")
        #expect(keys.report(for: lumen)?.reason == "No target builds dev.example.lumen.")
        let key = try #require(try await read()["infoPlistKey"])
        #expect(key["state"] == "unknown")
        #expect(key["report"]?["status"] == "couldNotAdd")
    }

    @Test func getExportComplianceSaysWhetherItCanBeAdded() async throws {
        let unconfirmed = try #require(try await read()["infoPlistKey"])
        #expect(unconfirmed["canAdd"] == false)
        #expect(unconfirmed["whyNot"]?["code"] == "unconfirmedSuggestion")
        #expect(unconfirmed["expected"] == .null)
        #expect(unconfirmed["next"]?.stringValue?.contains("Don't add the key") == true)

        confirm()
        let ready = try #require(try await read()["infoPlistKey"])
        #expect(ready["canAdd"] == true)
        #expect(ready["expected"]?["value"] == "NO")
        #expect(ready["expected"]?["buildSettings"] == ["INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO"])
        #expect(ready["expected"]?["settledBy"] == "answers")
        #expect(ready["next"]?.stringValue?.contains("Add It to the Project") == true)
    }

    /// Nobody answered in Atlas, and the newest uploads arrived answered.
    @Test func uploadsThatArriveAnsweredAreInferred() async throws {
        var withBuilds = services
        withBuilds.notes.setNotes(AppInformationNotes(), for: lumen)
        withBuilds.sampleBuilds = [
            EncryptionKeyBuild(id: "b44", number: "44", usesNonExemptEncryption: false),
            EncryptionKeyBuild(id: "b43", number: "43", usesNonExemptEncryption: false),
        ]
        let result = try await read(withBuilds)
        #expect(result["answersFromBuild"] == true)
        // The build's false reads as exempt encryption, not "none".
        #expect(result["answers"]?["usesEncryption"] == true)
        #expect(result["answers"]?["exempt"] == true)
        let key = try #require(result["infoPlistKey"])
        #expect(key["state"] == "inferred")
        #expect(key["present"] == true)
        #expect(key["how"]?.stringValue?.contains("Inferred only") == true)
        #expect(key["expected"]?["settledBy"] == "build")
        #expect(key["next"]?.stringValue?.contains("Inferred from the uploads only") == true)
    }

    /// An assistant's answers equal to what the build implies still show
    /// for the person to confirm: they aren't "unchanged".
    @Test func answersTheBuildOnlyImpliesStillShowAsASuggestion() async throws {
        services.notes.setNotes(AppInformationNotes(), for: lumen)
        let outcome = try await ProposeExportComplianceTool().call(
            MCPToolArguments(["appId": "Lumen", "usesEncryption": true, "exempt": true, "why": "Only HTTPS."]), in: context()
        )
        #expect(outcome.result["status"] == "kept")
        #expect(services.notes.notes(for: lumen).exportEvidence?.why == "Only HTTPS.")
    }

    @Test func theToolIsInTheToolboxAndChangesOnlyAtlas() {
        #expect(MCPToolbox.standard.toolNames.contains("report_encryption_key"))
        let definition = ReportEncryptionKeyTool().definition
        #expect(definition.proposalKind == nil)
        #expect(definition.changesState)
        #expect(MCPEndpoint.instructions.contains("report_encryption_key"))
        #expect(GetExportComplianceTool().definition.description.contains("infoPlistKey"))
    }
}
#endif
