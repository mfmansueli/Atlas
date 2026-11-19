//
//  AppComplianceViewModelTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// App Compliance in the section's view model, on the sample services:
/// Lumen has no trader status in the EU, no ICP Filing Number in China
/// mainland, and Health & Fitness as its secondary category. The answers
/// stay on this Mac; only "Stop selling in China mainland" is queued.
@MainActor
@Suite("AppInformationViewModel compliance")
struct AppComplianceViewModelTests {
    private let queue = ChangeQueue()
    private let app = StoreApp(id: DebugFixtures.AppID.lumen, name: "Lumen Journal", bundleID: "dev.example.lumen", sku: nil, primaryLocale: "en-US")
    private var stopSellingID: String { "appInformation.\(app.id).appCompliance.availability.CHN" }

    private func loaded(_ services: DebugAppInformationServices = DebugAppInformationServices(), app: StoreApp? = nil) async -> AppInformationViewModel {
        let viewModel = AppInformationViewModel(app: app ?? self.app, services: services, queue: queue)
        await viewModel.load()
        return viewModel
    }

    // MARK: - The page

    @Test func fiveNeedThePersonAndOneIsCheckedOnItsOwn() async throws {
        let vm = await loaded()
        let report = try #require(vm.complianceReport)
        #expect(report.state(of: .traderStatus) == .needsAnswer)
        #expect(report.state(of: .icpFilingNumber) == .needsAnswer)
        #expect(report.state(of: .securityAssessment) == .needsAnswer)
        #expect(report.state(of: .aiGeneratedContent) == .needsAnswer)
        #expect(report.state(of: .vietnamGameLicense) == .passes)
        #expect(report.medicalDevice == .category("HEALTH_AND_FITNESS"))
        #expect(vm.status(for: .appCompliance) == "5 need you")
        #expect(vm.pageColumnStatus(for: .appCompliance) == "5 need you")
        #expect(!vm.isPageUpToDate(.appCompliance))
        #expect(!vm.hasPendingChanges(on: .appCompliance))
    }

    /// Apple asks China mainland's two declarations of every app sold
    /// there, even when it shows nothing missing.
    @Test func anAppWithNothingMissingOnlyNeedsChinasDeclarations() async {
        let habitat = StoreApp(id: DebugFixtures.AppID.habitat, name: "Habitat", bundleID: "dev.example.habitat", sku: nil, primaryLocale: "en-US")
        let vm = await loaded(app: habitat)
        #expect(vm.status(for: .appCompliance) == "2 need you")
        #expect(vm.complianceReport?.state(of: .securityAssessment) == .needsAnswer)
        #expect(vm.complianceReport?.state(of: .aiGeneratedContent) == .needsAnswer)

        vm.setDeclared(true, for: .securityAssessment)
        vm.setDeclared(true, for: .aiGeneratedContent)
        #expect(vm.status(for: .appCompliance) == "Up to date")
        #expect(vm.isPageUpToDate(.appCompliance))
    }

    @Test func complianceIsNeverSuggestedOrTakenByAcceptAll() async {
        let vm = await loaded()
        #expect(!AppInformationViewModel.suggestionPages.contains(.appCompliance))
        #expect(vm.suggestionScopes(on: .appCompliance).isEmpty)
        #expect(vm.suggestionCount(on: .appCompliance) == 0)
        #expect(!vm.showsSuggestions(on: .appCompliance))
        #expect(!vm.acceptAllSelection().groups.contains { $0.id == AppInformationPage.appCompliance.rawValue })

        vm.acceptAllPages(withoutAsking: true)
        #expect(vm.status(for: .appCompliance) == "5 need you")
        #expect(vm.notes.compliance == ComplianceAnswers())
    }

    @Test func countriesThatCannotBeReadSayWhyAndLeaveTheOtherPagesAlone() async {
        var services = DebugAppInformationServices()
        services.complianceError = .server(statusCode: 500, code: "UNEXPECTED_ERROR", detail: nil)
        let vm = await loaded(services)
        #expect(vm.isLoaded)
        #expect(vm.complianceReport == nil)
        #expect(vm.compliance.value == nil)
        #expect(vm.status(for: .appCompliance) == nil)
        #expect(vm.complianceErrorLine == "500 · UNEXPECTED_ERROR · GET /v1/apps/\(app.id)/appAvailabilityV2")
        #expect(vm.status(for: .general) == "Lifestyle · Health & Fitness")
    }

    @Test func changingTheCategoryChecksAgain() async throws {
        let vm = await loaded()
        vm.setSecondaryCategory(nil)
        let report = try #require(vm.complianceReport)
        #expect(report.medicalDevice == .notNeeded)
        #expect(vm.status(for: .appCompliance) == "4 need you")

        vm.setPrimaryCategory("GAMES")
        #expect(vm.complianceReport?.gameLicense == .needed)
        #expect(vm.status(for: .appCompliance) == "5 need you")
    }

    @Test func aFrequentAnswerInAgeRatingChecksAgain() async {
        let vm = await loaded()
        vm.setSecondaryCategory(nil)
        vm.setAnswer(.frequent, for: .medical)
        #expect(vm.complianceReport?.medicalDevice == .frequentMedicalInformation)
    }

    // MARK: - Digital Services Act

    @Test func theTraderDetailsArePreparedFromTheTeamAndAppReviewsContact() async {
        let vm = await loaded()
        vm.sellerName = "Northpier Studio Ltd"
        #expect(vm.traderDetails == TraderDetails(name: "Northpier Studio Ltd", address: "", phone: "+39 011 555 0142", email: "review@northpier.dev"))
        #expect(vm.notes.compliance.traderDetails == nil)
    }

    @Test func decidingTraderKeepsTheAnswerHereAndQueuesNothing() async {
        let vm = await loaded()
        vm.sellerName = "Northpier Studio Ltd"
        vm.isEditingTrader = true
        vm.setTraderDetail("14 Harbour Road, Dublin 2", for: .address)
        vm.decideTrader(.trader)

        #expect(vm.notes.compliance.trader == .trader)
        #expect(vm.notes.compliance.traderDetails?.address == "14 Harbour Road, Dublin 2")
        #expect(vm.notes.compliance.traderDetails?.name == "Northpier Studio Ltd")
        #expect(!vm.isEditingTrader)
        #expect(queue.changes.isEmpty)
        #expect(vm.complianceReport?.state(of: .traderStatus) == .toEnter)
        #expect(vm.status(for: .appCompliance) == "4 need you")
        #expect(vm.toast?.contains("App Store Connect") == true)
    }

    @Test func stayingANonTraderAlsoWaitsForAppStoreConnectAndChangeReopensIt() async {
        let vm = await loaded()
        vm.decideTrader(.nonTrader)
        #expect(vm.complianceReport?.state(of: .traderStatus) == .toEnter)
        #expect(vm.notes.compliance.traderDetails == nil)

        vm.reopenTrader()
        #expect(vm.notes.compliance.trader == nil)
        #expect(vm.complianceReport?.state(of: .traderStatus) == .needsAnswer)
    }

    @Test func thePreviewShowsTheTradersDetailsOnceDecided() async {
        let vm = await loaded()
        vm.sellerName = "Northpier Studio Ltd"
        #expect(vm.traderPreview(showsSuggested: true) == .nonTrader)

        vm.decideTrader(.trader)
        #expect(vm.traderPreview(showsSuggested: false) == .details("Northpier Studio Ltd · +39 011 555 0142 · review@northpier.dev", isSuggested: false))

        vm.decideTrader(.nonTrader)
        #expect(vm.traderPreview(showsSuggested: true) == .nonTrader)
    }

    // MARK: - ICP Filing Number

    @Test func aNumberIsCheckedForItsFormatAndKeptHere() async {
        let vm = await loaded()
        #expect(vm.icpChoice == nil)
        vm.chooseICP(.addNumber)
        vm.setICPNumber("ICP 123")
        #expect(vm.icpChoice == .addNumber)
        #expect(vm.complianceReport?.answers.hasMalformedICPNumber == true)
        #expect(vm.complianceReport?.state(of: .icpFilingNumber) == .needsAnswer)

        vm.setICPNumber(DebugAppInformationContent.icpNumber)
        #expect(vm.complianceReport?.state(of: .icpFilingNumber) == .toEnter)
        #expect(queue.changes.isEmpty)
    }

    @Test func stoppingSalesInChinaQueuesTheAvailabilityChange() async throws {
        let vm = await loaded()
        vm.chooseICP(.stopSelling)

        let change = try #require(queue.change(id: stopSellingID))
        #expect(change.requests.map(\.path) == ["/v1/territoryAvailabilities/lumen-availability-CHN"])
        #expect(AppInformationTestSupport.attributes(change.requests.first)["available"] as? Bool == false)
        #expect(vm.icpChoice == .stopSelling)
        #expect(vm.complianceReport?.state(of: .icpFilingNumber) == .notPushed)
        #expect(vm.hasPendingChanges(on: .appCompliance))
        #expect(vm.status(for: .appCompliance) == "2 need you")
    }

    @Test func discardingTheChangeInReviewTakesTheChoiceBack() async {
        let vm = await loaded()
        vm.chooseICP(.stopSelling)
        queue.discard(id: stopSellingID)
        #expect(vm.icpChoice == nil)
        #expect(vm.complianceReport?.state(of: .icpFilingNumber) == .needsAnswer)
        #expect(!vm.hasPendingChanges(on: .appCompliance))
    }

    @Test func choosingTheNumberInsteadDiscardsTheAvailabilityChange() async {
        let vm = await loaded()
        vm.chooseICP(.stopSelling)
        vm.chooseICP(.addNumber)
        #expect(queue.changes.isEmpty)
        #expect(vm.icpChoice == .addNumber)

        vm.chooseICP(.stopSelling)
        #expect(queue.change(id: stopSellingID) != nil)
        #expect(!vm.notes.compliance.addsICPNumber)
    }

    // MARK: - Declared in App Store Connect

    @Test func markingTheMedicalDeviceDeclarationSettlesItAndChangeReopensIt() async {
        let vm = await loaded()
        vm.setDeclared(true, for: .medicalDevice)
        #expect(vm.complianceReport?.state(of: .medicalDevice) == .passes)
        #expect(vm.complianceReport?.isMarkedDeclared(.medicalDevice) == true)
        #expect(vm.status(for: .appCompliance) == "4 need you")

        vm.setDeclared(false, for: .medicalDevice)
        #expect(vm.complianceReport?.state(of: .medicalDevice) == .needsAnswer)
    }

    @Test func everythingAnsweredLeavesWhatIsForAppStoreConnect() async {
        let vm = await loaded()
        vm.decideTrader(.trader)
        vm.chooseICP(.addNumber)
        vm.setICPNumber(DebugAppInformationContent.icpNumber)
        vm.setDeclared(true, for: .medicalDevice)
        vm.chooseChina(.no, for: .securityAssessment)
        vm.chooseChina(.no, for: .aiGeneratedContent)
        #expect(vm.status(for: .appCompliance) == "4 to finish at Apple")
        #expect(!vm.isPageUpToDate(.appCompliance))
        #expect(vm.complianceReport?.headline == "4 to enter in App Store Connect · 2 checked")
    }
}
#endif
