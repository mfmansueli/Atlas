//
//  ComplianceRunPlanTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// App Compliance and Export Compliance in a Suggest Everything run:
/// `begin_suggestions` plans them beside the fields, skipping what Apple
/// doesn't ask about, and the run's rows name them.
@MainActor
@Suite("Suggest Everything plans compliance")
struct ComplianceRunPlanTests {
    private let store = FieldSuggestionStore()
    private let lumen = StoreApp(id: DebugFixtures.AppID.lumen, name: "Lumen Information", bundleID: "dev.example.info", sku: nil, primaryLocale: "en-US")

    private func context() -> MCPToolContext {
        var workspace = MCPTestFixtures.workspace(apps: [lumen], appInformation: DebugAppInformationServices())
        workspace.suggestions = store
        return MCPToolContext(workspace: workspace, clientName: "Claude Code")
    }

    private func entry(_ page: String, _ field: String) -> JSONValue {
        ["area": "info", "page": .string(page), "field": .string(field)]
    }

    @Test func compliancePlansBesideTheFields() async throws {
        let plan: [JSONValue] = [
            entry("general", "copyright"),
            entry("appCompliance", "traderStatus"),
            entry("appCompliance", "medicalDevice"),
            entry("appCompliance", "vietnamGameLicense"),
            entry("appCompliance", "exportCompliance"),
            entry("exportCompliance", "encryption"),
            entry("exportCompliance", "usesEncryption"),
        ]
        let outcome = try await BeginSuggestionsTool().call(MCPToolArguments(["appId": .string(lumen.id), "plan": .array(plan)]), in: context())
        #expect(outcome.result["accepted"] == 4)
        let skipped = try #require(outcome.result["skipped"]?.arrayValue)
        #expect(skipped.compactMap { $0["field"]?.stringValue } == ["vietnamGameLicense", "exportCompliance", "usesEncryption"])
        #expect(skipped.map { $0["code"] } == ["unknown_field", "unknown_field", "unknown_field"])

        let run = try #require(store.run)
        #expect(run.plan.contains(MCPComplianceRunTarget.target(for: .traderStatus)))
        #expect(run.plan.contains(MCPComplianceRunTarget.encryption))
        #expect(run.rows.map(\.page) == [.general, .appCompliance, .exportCompliance])
        #expect(run.rows.last?.detail == "Encryption")
    }

    @Test func aRegulationAppleDoesntAskAboutIsSkippedWithWhy() throws {
        let report = ComplianceTestSupport.report(ComplianceTestSupport.content(sold: [ComplianceTestSupport.unitedStates: []]))
        let item = try MCPSuggestionItem(["page": "appCompliance", "field": "icpFilingNumber"], isPlanned: true)
        guard case let .failure(skip)? = MCPComplianceRunTarget.planned(item, report: report) else {
            Issue.record("Expected the ICP Filing Number to be skipped outside China mainland")
            return
        }
        #expect(skip.code == "invalid_value")
        let other = try MCPSuggestionItem(["page": "general", "field": "copyright"], isPlanned: true)
        #expect(MCPComplianceRunTarget.planned(other, report: report) == nil)
    }

    @Test func thePagesAreNamedAsTheRunShowsThem() {
        #expect(SuggestionPage(.appInformation(.appCompliance)) == .appCompliance)
        #expect(SuggestionPage(.appInformation(.exportCompliance)) == .exportCompliance)
        #expect(SuggestionPage.appCompliance.title == "App Compliance")
        #expect(SuggestionPage.exportCompliance.appInformationPage == .exportCompliance)
        #expect(SuggestionPage.fieldTitle(of: MCPComplianceRunTarget.target(for: .icpFilingNumber)) == "ICP Filing Number")
        #expect(!SuggestionPage.fieldPages.contains(.appCompliance))
        #expect(MCPComplianceRunTarget.page(named: "app_compliance") == .appCompliance)
        #expect(MCPComplianceRunTarget.page(named: "review") == nil)
    }
}
#endif
