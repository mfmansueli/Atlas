//
//  AppInformationPageStripViewModelTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Each page's card from the view model on the sample services: what it
/// knows is missing, the suggestions waiting, and every card Ready once
/// Accept All Pages takes the suggestions of an otherwise finished app.
@MainActor
@Suite("App Information page strip")
struct AppInformationPageStripViewModelTests {
    private let queue = ChangeQueue()
    private let app = StoreApp(id: DebugFixtures.AppID.lumen, name: "Lumen Journal", bundleID: "dev.example.lumen", sku: nil, primaryLocale: "en-US")

    private func loaded(
        _ services: DebugAppInformationServices = DebugAppInformationServices(),
        suggestions: FieldSuggestionStore = FieldSuggestionStore()
    ) async -> AppInformationViewModel {
        let viewModel = AppInformationViewModel(app: app, services: services, queue: queue, suggestions: suggestions)
        await viewModel.load()
        return viewModel
    }

    /// Lumen as `info-accept-all` has it: done but for its suggestions.
    private func finishedButForSuggestions() async -> AppInformationViewModel {
        var services = DebugAppInformationServices(privacy: DebugPrivacyWorksheets.published)
        services.hasOutdatedDetails = true
        services.lumenCompliance = DebugAppInformationContent.settledCompliance
        let vm = await loaded(services, suggestions: SuggestionsDebugData.store(includesCodeAnswers: true))
        vm.setAnswer(.negative, for: .advertising)
        for rule in [ComplianceRule.securityAssessment, .aiGeneratedContent, .medicalDevice, .vietnamGameLicense] {
            vm.setDeclared(true, for: rule)
        }
        return vm
    }

    @Test func beforeLoadingEveryCardButAppPrivacyIsASkeleton() {
        let vm = AppInformationViewModel(app: app, services: DebugAppInformationServices(), queue: queue)
        for page in AppInformationPage.allCases where page != .appPrivacy {
            #expect(vm.pageStatus(for: page).isLoading, "\(page)")
        }
        // The worksheet is on this Mac.
        #expect(!vm.pageStatus(for: .appPrivacy).isLoading)
    }

    @Test func theSampleSaysWhatNeedsThePerson() async {
        let vm = await loaded()
        #expect(vm.pageStatus(for: .general).isReady)
        #expect(vm.pageStatus(for: .appReview).isReady)
        #expect(vm.pageStatus(for: .exportCompliance).isReady)
        #expect(vm.pageStatus(for: .accessibility).isReady)
        #expect(vm.pageStatus(for: .appCompliance).state == .needsYou(5))
        // Out of date with App Store Connect.
        #expect(vm.needsYouCount(on: .appPrivacy) >= 1)
        #expect(vm.needsYouCount(on: .ageRating) == vm.unansweredCount(on: .ageRating))
        #expect(vm.needsYouCount(on: .ageRating) > 0)
    }

    @Test func emptyContactDetailsNeedThePerson() async {
        let vm = await loaded()
        vm.setReviewText("", for: .phone)
        #expect(vm.needsYouCount(on: .appReview) == 1)
        // The built-in check may suggest 1.3's phone: then it shows first.
        #expect(!vm.pageStatus(for: .appReview).isReady)
    }

    @Test func aFailedLoadSaysSoOnThePagesItHolds() async {
        let vm = await loaded(DebugAppInformationServices(error: .server(statusCode: 500, detail: nil)))
        #expect(vm.pageStatus(for: .general).state == .failed)
        #expect(vm.pageStatus(for: .appReview).state == .failed)
    }

    @Test func suggestionsShowOnTheirPagesCard() async {
        let vm = await finishedButForSuggestions()
        // The 1.3 copyright and Claude Code's secondary category and release.
        #expect(vm.pageStatus(for: .general).state == .suggested(3))
        #expect(vm.pageStatus(for: .appReview).state == .suggested(vm.suggestionCount(on: .appReview)))
        #expect(vm.suggestionCount(on: .ageRating) > 0)
        #expect(vm.pageStatus(for: .appCompliance).isReady)
        #expect(vm.pageStatus(for: .appPrivacy).isReady)
        #expect(vm.pageStatus(for: .exportCompliance).isReady)
    }

    @Test func acceptingThisPageLeavesItReady() async {
        let vm = await finishedButForSuggestions()
        vm.acceptSuggestions(onPage: .general)
        #expect(vm.pageStatus(for: .general).isReady)
        #expect(!vm.pageStatus(for: .ageRating).isReady, "Only this page's are taken.")
    }

    @Test func acceptAllPagesLeavesEveryCardReady() async {
        let vm = await finishedButForSuggestions()
        let before = vm.pageBarModel(on: .general, acceptsRightAway: true).totalCount
        #expect(before > 0)
        #expect(AppInformationReviewEstimate.text(for: before).hasSuffix("min"))

        vm.acceptAllPages(withoutAsking: true)
        for page in AppInformationPage.allCases {
            #expect(vm.pageStatus(for: page).isReady, "\(page): \(String(describing: vm.pageStatus(for: page).state))")
        }
        #expect(vm.pageBarModel(on: .general, acceptsRightAway: true).totalCount == 0)
    }
}
#endif
