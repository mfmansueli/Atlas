//
//  SuggestAllCompliancePromptTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `suggest_all` answers App Compliance and Export Compliance from the
/// project as part of the run, and What It Covers lists them.
@MainActor
@Suite("Suggest Everything compliance")
struct SuggestAllCompliancePromptTests {
    private func text(_ prompt: MCPPrompt) -> String {
        prompt.message(app: "Alba")["messages"]?.arrayValue?.first?["content"]?["text"]?.stringValue ?? ""
    }

    @Test func suggestAllAnswersComplianceBeforeTheRunEnds() {
        let text = text(.suggestAll)
        #expect(text.contains(MCPPrompt.complianceStep))
        for tool in ["get_compliance", "propose_compliance_answers", "get_export_compliance", "propose_export_compliance"] {
            #expect(text.contains(tool), "suggest_all doesn't mention \(tool)")
        }
        #expect(MCPPrompt.complianceStep.contains("before end_suggestions"))
        #expect(MCPPrompt.complianceStep.contains("page: exportCompliance, field: encryption"))
        #expect(MCPPrompt.complianceStep.contains("ITSAppUsesNonExemptEncryption"))
        #expect(MCPPrompt.complianceStep.contains("Only stopSelling becomes a change in Review & Push"))
    }

    @Test func fillComplianceSaysWhichAnswerIsPushed() {
        #expect(text(.fillCompliance).contains("only stopSelling becomes a change in Review & Push"))
    }

    @Test func theToolDescriptionsSayWhatIsPushed() {
        let compliance = ProposeComplianceAnswersTool().definition.description
        #expect(compliance.contains("pushedWhenAccepted"))
        #expect(compliance.contains("propose_availability"))
        #expect(compliance.contains("marks them as declared"))
        #expect(ProposeExportComplianceTool().definition.description.contains("encryption declaration"))
        #expect(MCPEndpoint.instructions.contains("propose_export_compliance"))
    }

    // MARK: - What It Covers

    @Test func whatItCoversListsComplianceAndThePromptAsksForIt() {
        let content = DebugAppInformationContent.lumen(versionID: nil)
        let builder = AppInformationChangeBuilder(appID: DebugFixtures.AppID.lumen, ids: content.ids, versionString: content.version?.versionString)
        let slots = AppInformationSlotValues(content: content, accessibility: nil, builder: builder, changes: [])
        // Sold in the EU without a trader status, so the Digital Services Act
        // is open for an answer.
        let report = ComplianceTestSupport.report(ComplianceTestSupport.content(sold: [
            ComplianceTestSupport.germany: [ComplianceContent.traderNotProvided], ComplianceRegion.chinaMainland: [],
            ComplianceTestSupport.unitedStates: [],
        ]))
        let scope = SuggestEverythingScope(
            appName: "Lumen Journal",
            listing: StorePageContentFixtures.editable.listing(),
            information: slots,
            compliance: report
        )
        #expect(Array(scope.rows.map(\.page).suffix(2)) == [.appCompliance, .exportCompliance])
        #expect(scope.rows.last?.detail == "Encryption, for build 42")
        #expect(scope.complianceDetail?.contains("Digital Services Act") == true)
        #expect(scope.coversExportCompliance)
        #expect(scope.prompt.hasSuffix(SuggestEverythingScope.complianceRequest))

        let unread = SuggestEverythingScope(appName: "Lumen Journal", listing: StorePageContentFixtures.editable.listing(), information: slots)
        #expect(!unread.rows.map(\.page).contains(.appCompliance))
        #expect(!unread.prompt.contains("propose_export_compliance"))
    }
}
#endif
