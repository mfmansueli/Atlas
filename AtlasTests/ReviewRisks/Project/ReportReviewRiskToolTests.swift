//
//  ReportReviewRiskToolTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `report_review_risk`: an assistant confirms a risk it found in the
/// project, or clears one it read the code for.
@MainActor
@Suite("report_review_risk")
struct ReportReviewRiskToolTests {
    private let center = ReviewRiskCenter(directory: nil)
    private let lumen = MCPTestFixtures.apps[0]

    private func call(_ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        var all: [String: JSONValue] = ["appId": "Lumen Journal"]
        all.merge(arguments) { $1 }
        let context = MCPToolContext(workspace: MCPTestFixtures.workspace(), clientName: "Claude Code")
        return try await ReportReviewRiskTool(center: center).call(MCPToolArguments(all), in: context)
    }

    private let confirmed: [String: JSONValue] = [
        "check": "accountDeletion",
        "verdict": "confirmed",
        "title": "No way to delete an account",
        "why": "Sign-up in 2 screens, and no Delete Account anywhere.",
        "evidence": "Lumen/Account/SignUpView.swift:42",
        "excerpt": "try await Auth.auth().createUser(withEmail: email, password: password)",
        "advice": "Add Delete Account in Settings and say where in the App Review notes.",
        "level": "likely",
        "howSure": 3,
    ]

    @Test func confirmedAddsTheRiskTaggedWithTheAssistant() async throws {
        let outcome = try await call(confirmed)
        #expect(outcome.result["status"] == "confirmed")
        #expect(outcome.result["riskId"] == "accountDeletion:app")
        let risk = try #require(center.entry(for: lumen.id).reported["accountDeletion:app"])
        #expect(risk.foundBy == "Claude Code")
        #expect(risk.level == .likely)
        #expect(risk.howSure == .sure)
        #expect(risk.evidence.first?.place == "Lumen/Account/SignUpView.swift:42")
    }

    @Test func aRiskIDNamesTheSubject() async throws {
        var arguments = confirmed
        arguments["check"] = "purposeStrings"
        arguments["riskId"] = "purposeStrings:missing.NSCameraUsageDescription"
        _ = try await call(arguments)
        #expect(center.entry(for: lumen.id).reported["purposeStrings:missing.NSCameraUsageDescription"] != nil)
    }

    @Test func aRiskIDOfAnotherCheckIsRefused() async throws {
        var arguments = confirmed
        arguments["riskId"] = "purposeStrings:missing.NSCameraUsageDescription"
        let outcome = try await call(arguments)
        #expect(outcome.result["status"] == "refused")
        #expect(center.entry(for: lumen.id).reported.isEmpty)
    }

    @Test func clearedTakesTheRiskOutAndKeepsWhereTheCodeShowsIt() async throws {
        _ = try await call(confirmed)
        let outcome = try await call(["check": "accountDeletion", "verdict": "cleared", "evidence": "Lumen/Settings/AccountView.swift:88"])
        #expect(outcome.result["status"] == "cleared")
        let entry = center.entry(for: lumen.id)
        #expect(entry.reported.isEmpty)
        #expect(entry.cleared["accountDeletion:app"]?.evidence == "Lumen/Settings/AccountView.swift:88")
        #expect(entry.cleared["accountDeletion:app"]?.author == "Claude Code")
    }

    @Test func aLongTitleIsRefused() async throws {
        var arguments = confirmed
        arguments["title"] = "Accounts made in the app can never be deleted by anyone"
        let outcome = try await call(arguments)
        #expect(outcome.result["status"] == "refused")
        #expect(center.entry(for: lumen.id).reported.isEmpty)
    }

    @Test func wordsAtlasNeverWritesAreRefused() async throws {
        var arguments = confirmed
        arguments["advice"] = "Just add Delete Account in Settings."
        let outcome = try await call(arguments)
        #expect(outcome.result["status"] == "refused")
        #expect(outcome.result["reason"]?.stringValue?.contains("just") == true)
    }

    @Test func aConfirmedRiskNeedsItsTitleWhyAndAdvice() async throws {
        let outcome = try await call(["check": "signInWithApple", "verdict": "confirmed", "evidence": "Lumen/Login/LoginView.swift:3"])
        #expect(outcome.result["status"] == "refused")
    }

    @Test func anUnknownCheckOrLevelThrows() async throws {
        await #expect(throws: MCPToolError.self) {
            _ = try await call(["check": "nope", "verdict": "cleared", "evidence": "x.swift:1"])
        }
        var arguments = confirmed
        arguments["level"] = "severe"
        await #expect(throws: MCPToolError.self) {
            _ = try await call(arguments)
        }
    }

    @Test func itIsRegisteredAndChangesState() throws {
        let tool = try #require(MCPToolbox.standard.tool(named: "report_review_risk"))
        #expect(!tool.definition.isReadOnly)
        #expect(tool.definition.proposalKind == nil)
        #expect(tool.definition.description.count <= 700)
    }
}
