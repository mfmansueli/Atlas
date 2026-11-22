//
//  ChinaDeclarationViewModelTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The China mainland cards in the section's view model, on Lumen (sold
/// there): Yes and No are kept on this Mac; "Stop selling in China
/// mainland" is the change Apple's API takes, shared with the ICP card.
@MainActor
@Suite("AppInformationViewModel China declarations")
struct ChinaDeclarationViewModelTests {
    private let queue = ChangeQueue()
    private let app = StoreApp(id: DebugFixtures.AppID.lumen, name: "Lumen Journal", bundleID: "dev.example.lumen", sku: nil, primaryLocale: "en-US")
    private var stopSellingID: String { "appAvailability.\(app.id).CHN" }

    private func loaded() async -> AppInformationViewModel {
        let viewModel = AppInformationViewModel(app: app, services: DebugAppInformationServices(), queue: queue)
        await viewModel.load()
        return viewModel
    }

    @Test func answeringKeepsItHereAndQueuesNothing() async {
        let vm = await loaded()
        vm.chooseChina(.yes, for: .securityAssessment)
        vm.chooseChina(.no, for: .aiGeneratedContent)
        #expect(vm.chinaChoice(for: .securityAssessment) == .yes)
        #expect(vm.chinaChoice(for: .aiGeneratedContent) == .no)
        #expect(vm.notes.compliance.needsSecurityAssessment == true)
        #expect(vm.notes.compliance.aiContent == AIContentAnswer(offersAI: false))
        #expect(vm.complianceReport?.state(of: .securityAssessment) == .toEnter)
        #expect(vm.complianceReport?.state(of: .aiGeneratedContent) == .toEnter)
        #expect(queue.changes.isEmpty)
    }

    @Test func theAIFilingIsTypedAndKept() async {
        let vm = await loaded()
        vm.chooseChina(.yes, for: .aiGeneratedContent)
        #expect(vm.complianceReport?.state(of: .aiGeneratedContent) == .needsAnswer)
        vm.setAIFiling(DebugAppInformationContent.aiFiling)
        #expect(vm.aiFiling == DebugAppInformationContent.aiFiling)
        #expect(vm.complianceReport?.state(of: .aiGeneratedContent) == .toEnter)

        // No, then Yes again, keeps what was typed.
        vm.chooseChina(.no, for: .aiGeneratedContent)
        vm.chooseChina(.yes, for: .aiGeneratedContent)
        #expect(vm.aiFiling == DebugAppInformationContent.aiFiling)
    }

    @Test func stoppingSalesIsTheChangeTheICPCardShares() async throws {
        let vm = await loaded()
        vm.chooseChina(.stopSelling, for: .aiGeneratedContent)
        let change = try #require(queue.change(id: stopSellingID))
        #expect(change.requests.map(\.path) == ["/v1/territoryAvailabilities/lumen-availability-CHN"])
        #expect(vm.chinaChoice(for: .securityAssessment) == .stopSelling)
        #expect(vm.icpChoice == .stopSelling)
        #expect(vm.complianceReport?.state(of: .securityAssessment) == .toEnter)

        // Answering keeps the app on sale there.
        vm.chooseChina(.no, for: .securityAssessment)
        #expect(queue.change(id: stopSellingID) == nil)
        #expect(vm.chinaChoice(for: .securityAssessment) == .no)
        #expect(vm.chinaChoice(for: .aiGeneratedContent) == nil)
    }

    /// Not sold in China mainland: both start at No, with no Stop
    /// Selling choice, and a Yes is still the person's to give.
    @Test func outsideChinaMainlandBothStartAtNo() async {
        var services = DebugAppInformationServices()
        services.lumenCompliance = DebugAppInformationContent.complianceOutsideChina
        let vm = AppInformationViewModel(app: app, services: services, queue: queue)
        await vm.load()
        #expect(vm.chinaChoices == [.yes, .no])
        #expect(vm.chinaChoice(for: .securityAssessment) == .no)
        #expect(vm.chinaChoice(for: .aiGeneratedContent) == .no)
        #expect(vm.complianceReport?.state(of: .aiGeneratedContent) == .toEnter)
        vm.chooseChina(.yes, for: .aiGeneratedContent)
        #expect(vm.chinaChoice(for: .aiGeneratedContent) == .yes)
        #expect(vm.complianceReport?.state(of: .aiGeneratedContent) == .needsAnswer)
        vm.setDeclared(true, for: .securityAssessment)
        #expect(vm.complianceReport?.state(of: .securityAssessment) == .passes)
        #expect(queue.changes.isEmpty)
    }

    @Test func markAsDeclaredSettlesIt() async {
        let vm = await loaded()
        vm.chooseChina(.no, for: .securityAssessment)
        vm.setDeclared(true, for: .securityAssessment)
        #expect(vm.complianceReport?.state(of: .securityAssessment) == .passes)
        #expect(vm.complianceReport?.detail(for: .securityAssessment) == "You marked it as declared in App Store Connect.")
    }

    @Test func acceptingAnAssistantsAIAnswerFillsTheFiling() async {
        let vm = await loaded()
        let suggestion = ComplianceSuggestion(
            answer: .aiContent(AIContentAnswer(offersAI: true, filing: DebugAppInformationContent.aiFiling)),
            evidence: AssistantEvidence(client: "Claude Code", summary: "", why: "Reflect calls Mingyu's model.", evidence: [], couldNotSee: nil)
        )
        vm.notes.complianceSuggestions = [suggestion]
        #expect(vm.complianceSuggestion(for: .aiGeneratedContent) != nil)
        vm.acceptComplianceSuggestion(for: .aiGeneratedContent)
        #expect(vm.chinaChoice(for: .aiGeneratedContent) == .yes)
        #expect(vm.aiFiling == DebugAppInformationContent.aiFiling)
        #expect(vm.complianceSuggestion(for: .aiGeneratedContent) == nil)
        #expect(queue.changes.isEmpty)
    }
}
#endif
