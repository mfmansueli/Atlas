//
//  PrivacyURLsSuggestionBarTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// App Privacy's suggestion bar on Privacy URLs, on Lumen's sample: it
/// accepts and dismisses the User Privacy Choices URLs suggested per
/// language, its arrows go from language to language, and App Privacy's
/// answers (an assistant's scan in the worksheet) are never in it, in
/// Accept All Pages or in its counts.
@MainActor
@Suite("App Privacy · suggestion bar")
struct PrivacyURLsSuggestionBarTests {
    private let queue = ChangeQueue()
    private let store = FieldSuggestionStore()
    private let app = StoreApp(id: DebugFixtures.AppID.lumen, name: "Lumen Journal", bundleID: "dev.example.lumen", sku: nil, primaryLocale: "en-US")
    private let claude = SuggestionSource.assistant(client: "Claude Code")

    private func loaded(_ worksheet: PrivacyWorksheet = PrivacyWorksheet()) async -> AppInformationViewModel {
        let viewModel = AppInformationViewModel(
            app: app, services: DebugAppInformationServices(privacy: worksheet), queue: queue, suggestions: store
        )
        await viewModel.load()
        await viewModel.privacy.loadURLs()
        return viewModel
    }

    @discardableResult
    private func suggestChoices(_ locale: StoreLocale, _ url: String, on viewModel: AppInformationViewModel) -> FieldSuggestion {
        let suggestion = store.add(
            appID: app.id, target: AppInformationSuggestionSlot.privacyChoicesURL(locale).target, value: url, reason: "Its own page.", source: claude
        ).suggestion
        viewModel.refreshSuggestions()
        return suggestion
    }

    // MARK: - The bar

    @Test func appPrivacyHasABarForItsURLs() async {
        let viewModel = await loaded()
        #expect(viewModel.showsSuggestions(on: .appPrivacy))
        #expect(AppInformationViewModel.suggestionPages.contains(.appPrivacy))
        #expect(viewModel.barScopes(on: .appPrivacy).count == viewModel.privacy.urls.value?.locales.count)
        #expect(viewModel.barScopes(on: .general) == [.appInformation(.general)])
        #expect(!viewModel.showsSuggestions(on: .appCompliance))
        #expect(!viewModel.showsSuggestions(on: .exportCompliance))
    }

    @Test func acceptOnThisPageQueuesEveryLanguagesURL() async throws {
        let viewModel = await loaded()
        suggestChoices(.german, "https://lumen.example/de/choices", on: viewModel)
        suggestChoices(.french, "https://lumen.example/fr/choices", on: viewModel)
        let bar = viewModel.pageBarModel(on: .appPrivacy, acceptsRightAway: false)
        #expect(bar.hereCount == 2)
        #expect(bar.acceptHereTitle == "Accept 2 on This Page")
        #expect(viewModel.suggestionBar(for: viewModel.barScopes(on: .appPrivacy), assistant: nil).openCount == 2)

        viewModel.acceptSuggestions(onPage: .appPrivacy)
        let table = try #require(viewModel.privacy.urlsTable)
        #expect(queue.change(id: table.choicesBuilder.privacyChoicesChangeID(.german)) != nil)
        #expect(queue.change(id: table.choicesBuilder.privacyChoicesChangeID(.french)) != nil)
        #expect(viewModel.suggestionCount(on: .appPrivacy) == 0)
        #expect(viewModel.suggestionToast?.text == "Accepted 2 on App Privacy. They’re waiting in Review & Push, top right.")
    }

    @Test func dismissAllHereAndRestoreWorkOnEveryLanguage() async {
        let viewModel = await loaded()
        suggestChoices(.german, "https://lumen.example/de/choices", on: viewModel)
        suggestChoices(.french, "https://lumen.example/fr/choices", on: viewModel)
        let scopes = viewModel.barScopes(on: .appPrivacy)
        viewModel.dismissAllSuggestions(in: scopes)
        viewModel.refreshSuggestions()
        #expect(viewModel.suggestionCount(on: .appPrivacy) == 0)
        #expect(viewModel.suggestionBar(for: scopes, assistant: nil).dismissedCount == 2)
        #expect(queue.changes.isEmpty)

        viewModel.restoreDismissedSuggestions(in: scopes)
        viewModel.refreshSuggestions()
        #expect(viewModel.suggestionCount(on: .appPrivacy) == 2)
    }

    @Test func otherPagesCountAppPrivacysURLsInAcceptAllPages() async {
        let viewModel = await loaded()
        suggestChoices(.german, "https://lumen.example/de/choices", on: viewModel)
        let general = viewModel.pageBarModel(on: .general, acceptsRightAway: false)
        #expect(general.totalCount >= 1)
        #expect(general.otherPageCount >= 1)
        let groups = viewModel.acceptAllSelection().groups
        #expect(groups.contains { $0.title == AppInformationPage.appPrivacy.title })
    }

    /// An assistant's worksheet answers stay out of the bar: only the
    /// URLs count.
    @Test func privacyAnswersAreNeverInTheBar() async {
        let viewModel = await loaded(DebugPrivacyWorksheets.scanning(at: PrivacyTestSupport.date))
        #expect(viewModel.privacy.highConfidenceCount > 0)
        #expect(viewModel.pageBarModel(on: .appPrivacy, acceptsRightAway: false).hereCount == 0)
        #expect(viewModel.suggestionCount(on: .appPrivacy) == 0)
        #expect(!viewModel.acceptAllSelection().groups.contains { $0.title == AppInformationPage.appPrivacy.title })
        #expect(viewModel.suggestionSlots(in: viewModel.barScopes(on: .appPrivacy).first ?? .appInformation(.appPrivacy)).allSatisfy {
            if case .privacyChoicesURL = $0 { return true }
            return false
        })
    }

    // MARK: - Language to language

    @Test func theArrowsGoToTheLanguagesWithSuggestions() async throws {
        let viewModel = await loaded()
        suggestChoices(.german, "https://lumen.example/de/choices", on: viewModel)
        suggestChoices(.french, "https://lumen.example/fr/choices", on: viewModel)
        let navigation = viewModel.privacySuggestionNavigation
        #expect(Set(navigation.withSuggestions) == [.german, .french])
        let first = try #require(navigation.withSuggestions.first)
        let second = try #require(navigation.withSuggestions.last)
        #expect(navigation.next == first)
        #expect(navigation.previous == second)
        #expect(navigation.positionText == nil)

        viewModel.privacy.tab = .worksheet
        viewModel.showNextPrivacySuggestion()
        #expect(viewModel.privacy.tab == .urls)
        #expect(viewModel.privacy.focusedChoicesLocale == first)
        #expect(viewModel.privacySuggestionNavigation.positionText == "\(first.name), 1 of 2")
        viewModel.showNextPrivacySuggestion()
        #expect(viewModel.privacy.focusedChoicesLocale == second)
        viewModel.showNextPrivacySuggestion()
        #expect(viewModel.privacy.focusedChoicesLocale == first, "It wraps around.")
        viewModel.showNextPrivacySuggestion(forward: false)
        #expect(viewModel.privacy.focusedChoicesLocale == second)
    }

    @Test func openingAppPrivacysSuggestionsShowsTheFirstLanguage() async {
        let viewModel = await loaded()
        suggestChoices(.french, "https://lumen.example/fr/choices", on: viewModel)
        viewModel.openSuggestions(on: .appPrivacy)
        #expect(viewModel.page == .appPrivacy)
        #expect(viewModel.privacy.tab == .urls)
        #expect(viewModel.privacy.focusedChoicesLocale == .french)
    }

    @Test func navigationWrapsAndStopsWhenThereIsNowhereElse() {
        let locales: [StoreLocale] = [.englishUS, .german, .french]
        let none = PrivacyURLsSuggestionNavigation(locales: locales, suggested: [], current: nil)
        #expect(none.next == nil)
        #expect(none.previous == nil)
        #expect(!none.canMove)

        let one = PrivacyURLsSuggestionNavigation(locales: locales, suggested: [.german], current: .german)
        #expect(one.next == nil)
        #expect(!one.canMove)
        #expect(one.positionText == "\(StoreLocale.german.name), 1 of 1")

        let two = PrivacyURLsSuggestionNavigation(locales: locales, suggested: [.englishUS, .french], current: .german)
        #expect(two.next == .french)
        #expect(two.previous == .englishUS)
        #expect(two.canMove)
        #expect(two.positionText == nil, "German has nothing to review.")
        let atLast = PrivacyURLsSuggestionNavigation(locales: locales, suggested: [.englishUS, .french], current: .french)
        #expect(atLast.next == .englishUS)
    }
}
#endif
