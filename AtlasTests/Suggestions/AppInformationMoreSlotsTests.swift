//
//  AppInformationMoreSlotsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The slots beyond contact and notes on Lumen's sample: Games
/// subcategories (only for a game), sign-in required and the demo user
/// name, the app's accessibility URL, and each language's User Privacy
/// Choices URL; their values, what they can take and the changes they
/// queue.
@Suite("App Information: sign-in, subcategories and URLs")
struct AppInformationMoreSlotsTests {
    private let content = DebugAppInformationContent.lumen(versionID: nil)
    private let accessibility = DebugAppInformationContent.accessibility(.lumen)
    private let privacyURLs = DebugAppInformationContent.privacyURLs(
        for: StoreApp(id: DebugFixtures.AppID.lumen, name: "Lumen", bundleID: "dev.example.info", sku: nil, primaryLocale: "en-US")
    )
    private let claude = ChangeSource.assistant(client: "Claude Code")

    private func values(
        _ changes: [PendingChange] = [],
        content: AppInformationContent? = nil,
        privacy: Bool = true
    ) -> AppInformationSlotValues {
        let content = content ?? self.content
        let builder = AppInformationChangeBuilder(appID: DebugFixtures.AppID.lumen, ids: content.ids, versionString: content.version?.versionString)
        return AppInformationSlotValues(
            content: content, accessibility: accessibility, builder: builder, changes: changes, privacyURLs: privacy ? privacyURLs : nil
        )
    }

    private var game: AppInformationContent {
        var content = content
        content.general.primaryCategory = "GAMES"
        content.general.gamesSubcategories = ["GAMES_PUZZLE"]
        return content
    }

    // MARK: - Fields

    @Test func subcategoriesAreNormalizedByIDOrName() {
        let field = AppInformationSuggestionField.gamesSubcategories
        #expect(field.normalized("Puzzle, GAMES_WORD") == "GAMES_PUZZLE,GAMES_WORD")
        #expect(field.normalized("puzzle; trivia") == "GAMES_PUZZLE,GAMES_TRIVIA")
        #expect(field.normalized("Puzzle, Puzzle") == "GAMES_PUZZLE")
        #expect(field.normalized("") == "")
        #expect(field.normalized("Productivity") == nil)
        #expect(field.normalized("Puzzle, Word, Trivia") == nil)
        #expect(field.displayValue("GAMES_PUZZLE,GAMES_WORD") == "Puzzle, Word")
        #expect(field.displayValue("") == "None")
    }

    @Test func signInTakesYesOrNoAndTheReviewPagesNames() {
        let field = AppInformationSuggestionField.demoAccountRequired
        #expect(field.normalized("Yes") == "yes")
        #expect(field.normalized("false") == "no")
        #expect(field.normalized("sometimes") == nil)
        #expect(field.isNamed("signInRequired"))
        #expect(AppInformationSuggestionField.demoAccountName.isNamed("userName"))
        #expect(!AppInformationSuggestionField.allCases.contains { $0.isNamed("password") || $0.isNamed("demoAccountPassword") })
        #expect(field.reviewField == .signInRequired)
        #expect(AppInformationSuggestionField.demoAccountName.reviewField == .userName)
    }

    @Test func pagesAndLevels() {
        #expect(AppInformationSuggestionField.gamesSubcategories.page == .general)
        #expect(AppInformationSuggestionField.demoAccountName.page == .appReview)
        #expect(AppInformationSuggestionField.accessibilityURL.page == .accessibility)
        #expect(!AppInformationSuggestionField.gamesSubcategories.isVersionLevel)
        #expect(!AppInformationSuggestionField.accessibilityURL.isVersionLevel)
        #expect(AppInformationSuggestionField.demoAccountRequired.isVersionLevel)
        #expect(AppInformationSuggestionField.accessibilityURL.rawValue == "accessibilityUrl")
    }

    @Test func thePrivacyChoicesSlotRoundTripsItsTarget() throws {
        let slot = AppInformationSuggestionSlot.privacyChoicesURL(.german)
        #expect(slot.target == SuggestionTarget(.appPrivacy(locale: "de-DE"), field: "privacyChoicesUrl"))
        #expect(AppInformationSuggestionSlot(target: slot.target) == slot)
        #expect(AppInformationSuggestionSlot(target: SuggestionTarget(.appPrivacy(locale: "de-DE"), field: "privacyPolicyUrl")) == nil)
        #expect(slot.scope.page == .appPrivacy)
        #expect(slot.scope.area == .appInformation)
        #expect(SuggestionPage(slot.scope) == .appPrivacy)
        #expect(SuggestionPage(AppInformationSuggestionSlot.field(.accessibilityURL).scope) == .accessibility)
        #expect(!slot.canUseAndEdit)
        let encoded = try JSONEncoder().encode(slot.scope)
        #expect(try JSONDecoder().decode(SuggestionScope.self, from: encoded) == slot.scope)
    }

    // MARK: - Games subcategories

    @Test func subcategoriesNeedAGame() throws {
        #expect(!values().canSuggest(.field(.gamesSubcategories)))
        #expect(values().change(.field(.gamesSubcategories), to: "GAMES_PUZZLE", source: claude) == nil)

        let game = values(content: game)
        #expect(game.canSuggest(.field(.gamesSubcategories)))
        #expect(game.value(.field(.gamesSubcategories)) == "GAMES_PUZZLE")
        let written = try #require(game.change(.field(.gamesSubcategories), to: "GAMES_PUZZLE,GAMES_WORD", source: claude))
        let change = try #require(written.change)
        #expect(change.source == claude)
        let after = values([change], content: self.game)
        #expect(after.value(.field(.gamesSubcategories)) == "GAMES_PUZZLE,GAMES_WORD")
        #expect(after.isPending(.field(.gamesSubcategories)))
        #expect(after.liveValue(.field(.gamesSubcategories)) == "GAMES_PUZZLE")
    }

    // MARK: - Sign-in

    @Test func signInQueuesTheReviewDetailsSwitch() throws {
        #expect(values().value(.field(.demoAccountRequired)) == "no")
        let change = try #require(values().change(.field(.demoAccountRequired), to: "yes", source: claude)?.change)
        let after = values([change])
        #expect(after.value(.field(.demoAccountRequired)) == "yes")
        #expect(after.isPending(.field(.demoAccountRequired)))
        #expect(values().change(.field(.demoAccountRequired), to: "no", source: claude)?.change == nil)

        let name = try #require(values().change(.field(.demoAccountName), to: "review@lumen.example", source: claude)?.change)
        #expect(values([name]).value(.field(.demoAccountName)) == "review@lumen.example")
    }

    // MARK: - URLs

    @Test func theAccessibilityURLIsReadWithAccessibility() throws {
        let live = accessibility.accessibilityURL
        #expect(values().value(.field(.accessibilityURL)) == live)
        #expect(values().canSuggest(.field(.accessibilityURL)))
        let written = try #require(values().change(.field(.accessibilityURL), to: "https://lumen.example/a11y", source: claude))
        let change = try #require(written.change)
        let after = values([change])
        #expect(after.value(.field(.accessibilityURL)) == "https://lumen.example/a11y")
        #expect(after.isPending(.field(.accessibilityURL)))
        #expect(after.liveValue(.field(.accessibilityURL)) == live)

        let builder = AppInformationChangeBuilder(appID: DebugFixtures.AppID.lumen, ids: content.ids)
        let unread = AppInformationSlotValues(content: content, accessibility: nil, builder: builder, changes: [])
        #expect(!unread.canSuggest(.field(.accessibilityURL)))
    }

    @Test func thePrivacyChoicesURLIsOnePerLanguage() throws {
        let slot = AppInformationSuggestionSlot.privacyChoicesURL(.german)
        let live = try #require(privacyURLs.remote(.german)).choicesURL
        #expect(values().value(slot) == live)
        #expect(values().canSuggest(slot))
        #expect(!values(privacy: false).canSuggest(slot))
        #expect(values().privacyLocales.count == privacyURLs.locales.count)

        let written = try #require(values().change(slot, to: "https://lumen.example/de/choices", source: claude))
        let change = try #require(written.change)
        #expect(written.id == change.id)
        let after = values([change])
        #expect(after.value(slot) == "https://lumen.example/de/choices")
        #expect(after.isPending(slot))
        #expect(after.liveValue(slot) == live)
        #expect(!after.isPending(.privacyChoicesURL(.french)))
    }

    @Test func aQueuedVersionsPrivacyURLsUseItsPlaceholders() throws {
        let change = NewAppVersionChangeBuilder(appID: DebugFixtures.AppID.lumen).change(
            for: NewAppVersion(versionString: "1.5", platform: "IOS"),
            showsPlatform: false,
            source: claude
        )
        let queued = try #require(QueuedAppVersion(change: change))
        let content = queued.privacyURLsContent(from: privacyURLs)
        #expect(content.appInfoID == queued.appInfoToken)
        #expect(content.remote(.german)?.localizationID == queued.appInfoLocalizationToken(.german))
        #expect(content.remote(.german)?.choicesURL == privacyURLs.remote(.german)?.choicesURL)
    }
}
#endif
