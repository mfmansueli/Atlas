//
//  ComplianceSuggestionTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Assistant answers on App Compliance: they wait on their cards, count in
/// the page column, give the card's own answer when accepted, and are
/// never taken by Accept All.
@MainActor
@Suite("App Compliance suggestions")
struct ComplianceSuggestionTests {
    private let queue = ChangeQueue()
    private let app = StoreApp(id: DebugFixtures.AppID.lumen, name: "Lumen Journal", bundleID: "dev.example.lumen", sku: nil, primaryLocale: "en-US")
    private var stopSellingID: String { "appAvailability.\(app.id).CHN" }

    private func loaded(with suggestions: [ComplianceSuggestion] = DebugAppInformationContent.complianceSuggestions) async -> AppInformationViewModel {
        let viewModel = AppInformationViewModel(app: app, services: DebugAppInformationServices(), queue: queue)
        await viewModel.load()
        viewModel.notes.complianceSuggestions = suggestions
        return viewModel
    }

    private func suggestion(_ answer: ComplianceSuggestedAnswer) -> ComplianceSuggestion {
        ComplianceSuggestion(answer: answer, evidence: AssistantEvidence(client: "Claude Code", summary: answer.title, why: "Because.", evidence: []))
    }

    @Test func suggestionsWaitOnTheirCardsAndCountInThePageColumn() async {
        let vm = await loaded()
        #expect(vm.complianceSuggestions.map(\.rule) == [.traderStatus, .icpFilingNumber, .securityAssessment, .aiGeneratedContent, .medicalDevice])
        #expect(vm.suggestionCount(on: .appCompliance) == 5)
        #expect(vm.pageColumnStatus(for: .appCompliance) == "5 need you · 5 suggested")
        #expect(vm.complianceSuggestionBanner?.client == "Claude Code")
        #expect(vm.complianceSuggestionBanner?.text.hasPrefix("suggested 5 answers") == true)
        // Suggestions don't answer: the page still needs the person.
        #expect(vm.status(for: .appCompliance) == "5 need you")
    }

    @Test func acceptingTheTraderGivesTheCardsAnswerWithTheSuggestedDetails() async throws {
        let vm = await loaded()
        vm.acceptComplianceSuggestion(for: .traderStatus)
        #expect(vm.notes.compliance.trader == .trader)
        #expect(vm.traderDetails == DebugAppInformationContent.traderDetails)
        #expect(try #require(vm.complianceReport).state(of: .traderStatus) == .toEnter)
        #expect(vm.complianceSuggestion(for: .traderStatus) == nil)
        #expect(vm.notes.complianceSuggestions.map(\.rule) == [.icpFilingNumber, .securityAssessment, .aiGeneratedContent, .medicalDevice])
        #expect(vm.toast?.hasPrefix("Accepted Claude Code’s answer.") == true)
    }

    @Test func acceptingStopSellingQueuesTheChangeAsTheAssistants() async throws {
        let vm = await loaded()
        vm.acceptComplianceSuggestion(for: .icpFilingNumber)
        let change = try #require(queue.change(id: stopSellingID))
        #expect(change.source == .assistant(client: "Claude Code"))
        #expect(vm.icpChoice == .stopSelling)
        #expect(try #require(vm.complianceReport).state(of: .icpFilingNumber) == .notPushed)
    }

    @Test func acceptingAnICPNumberChoosesItAndDropsAQueuedStop() async throws {
        let vm = await loaded(with: [suggestion(.icpNumber(DebugAppInformationContent.icpNumber))])
        vm.chooseICP(.stopSelling)
        #expect(queue.change(id: stopSellingID) != nil)
        vm.acceptComplianceSuggestion(for: .icpFilingNumber)
        #expect(queue.change(id: stopSellingID) == nil)
        #expect(vm.icpChoice == .addNumber)
        #expect(vm.notes.compliance.hasValidICPNumber)
        #expect(try #require(vm.complianceReport).state(of: .icpFilingNumber) == .toEnter)
    }

    @Test func theMedicalDeviceAnswerIsLeftToDeclareAndCanChange() async throws {
        let vm = await loaded()
        vm.acceptComplianceSuggestion(for: .medicalDevice)
        let report = try #require(vm.complianceReport)
        #expect(vm.notes.compliance.regulatedMedicalDevice == false)
        #expect(report.state(of: .medicalDevice) == .toEnter)
        #expect(report.detail(for: .medicalDevice).hasPrefix("Your answer: Lumen Journal isn’t a regulated medical device."))

        vm.setDeclared(true, for: .medicalDevice)
        #expect(try #require(vm.complianceReport).state(of: .medicalDevice) == .passes)
        vm.setDeclared(false, for: .medicalDevice)
        vm.clearMedicalDeviceAnswer()
        #expect(try #require(vm.complianceReport).state(of: .medicalDevice) == .needsAnswer)
    }

    @Test func dismissingForgetsItWithoutAnswering() async {
        let vm = await loaded()
        vm.dismissComplianceSuggestion(for: .medicalDevice)
        #expect(vm.complianceSuggestion(for: .medicalDevice) == nil)
        #expect(vm.notes.compliance.regulatedMedicalDevice == nil)
        #expect(vm.toast == "Dismissed Claude Code’s answer.")
    }

    @Test func aSuggestionClosesOnceThePersonGivesTheSameAnswer() async {
        let vm = await loaded(with: [suggestion(.nonTrader)])
        #expect(vm.complianceSuggestion(for: .traderStatus) != nil)
        vm.decideTrader(.nonTrader)
        #expect(vm.complianceSuggestion(for: .traderStatus) == nil)
        #expect(vm.suggestionCount(on: .appCompliance) == 0)
    }

    @Test func acceptAllNeverTakesThem() async {
        let vm = await loaded()
        #expect(!vm.acceptAllSelection().groups.contains { $0.id == AppInformationPage.appCompliance.rawValue })
        vm.acceptAllPages(withoutAsking: true)
        #expect(vm.complianceSuggestions.count == 5)
        #expect(vm.notes.compliance == ComplianceAnswers())
        #expect(queue.change(id: stopSellingID) == nil)
    }

    @Test func notesSavedBeforeSuggestionsStillLoad() throws {
        let old = Data(#"{"overrideReason":"","compliance":{"trader":"nonTrader","declared":["medicalDevice"]}}"#.utf8)
        let notes = try JSONDecoder().decode(AppInformationNotes.self, from: old)
        #expect(notes.complianceSuggestions.isEmpty)
        #expect(notes.compliance.trader == .nonTrader)
        #expect(notes.compliance.regulatedMedicalDevice == nil)
    }

    @Test func suggestionsRoundTripThroughTheNotes() throws {
        var notes = AppInformationNotes()
        notes.complianceSuggestions = DebugAppInformationContent.complianceSuggestions
        notes.compliance.regulatedMedicalDevice = false
        let decoded = try JSONDecoder().decode(AppInformationNotes.self, from: JSONEncoder().encode(notes))
        #expect(decoded == notes)
    }
}
#endif
