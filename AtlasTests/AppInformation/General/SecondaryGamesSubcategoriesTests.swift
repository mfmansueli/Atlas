//
//  SecondaryGamesSubcategoriesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The secondary category's own pair of Games subcategories
/// (`secondarySubcategoryOne` and `secondarySubcategoryTwo` on the app
/// info): read, queued and shown with changes on top, edited on General
/// while the secondary category is Games, and suggested as
/// `secondaryGamesSubcategories`.
@MainActor
@Suite("App Information · secondary Games subcategories")
struct SecondaryGamesSubcategoriesTests {
    private typealias Support = AppInformationTestSupport
    private typealias Key = AppInformationChangeBuilder.GeneralKey
    private let claude = ChangeSource.assistant(client: "Claude Code")
    private let app = StoreApp(id: DebugFixtures.AppID.lumen, name: "Lumen Journal", bundleID: "dev.example.lumen", sku: nil, primaryLocale: "en-US")

    // MARK: - Changes

    @Test func theSecondaryPairIsItsOwnChange() throws {
        let change = try #require(Support.builder.gamesSubcategoriesChange(from: [], to: ["GAMES_PUZZLE", "GAMES_WORD"], secondary: true))
        #expect(change.id == "appInformation.\(Support.appID).general.secondaryGamesSubcategories")
        #expect(change.title == "Secondary Games subcategories")
        #expect(change.oldValue == "None")
        #expect(change.newValue == "Puzzle, Word")
        #expect(change.requests.first?.path == "/v1/appInfos/info-1")
        #expect(Support.relationshipID(change.requests.first, "secondarySubcategoryOne") == "GAMES_PUZZLE")
        #expect(Support.relationshipID(change.requests.first, "secondarySubcategoryTwo") == "GAMES_WORD")
        #expect(Support.relationshipID(change.requests.first, "primarySubcategoryOne") == nil)
        #expect(change.conflictCheck?.path == "/v1/appInfos/info-1/relationships/secondarySubcategoryOne")
        #expect(change.conflictCheck?.expected == nil)
        #expect(Support.builder.gamesSubcategoriesChange(from: ["GAMES_WORD"], to: ["GAMES_WORD"], secondary: true) == nil)

        let primary = try #require(Support.builder.gamesSubcategoriesChange(from: [], to: ["GAMES_PUZZLE"]))
        #expect(primary.id != change.id)
        #expect(Support.relationshipID(primary.requests.first, "primarySubcategoryOne") == "GAMES_PUZZLE")
    }

    @Test func clearingTheSecondaryPairSendsNullForBoth() throws {
        let change = try #require(Support.builder.gamesSubcategoriesChange(from: ["GAMES_PUZZLE"], to: [], secondary: true))
        let relationships = (Support.json(change.requests.first)["data"] as? [String: Any])?["relationships"] as? [String: Any]
        #expect((relationships?["secondarySubcategoryOne"] as? [String: Any])?["data"] is NSNull)
        #expect((relationships?["secondarySubcategoryTwo"] as? [String: Any])?["data"] is NSNull)
        #expect(Support.relationshipID(change.restoreRequests.first, "secondarySubcategoryOne") == "GAMES_PUZZLE")
    }

    @Test func aQueuedPairShowsOnTopOfAppStoreConnects() throws {
        let values = GeneralValues(primaryCategory: "LIFESTYLE", secondaryCategory: "GAMES", secondaryGamesSubcategories: ["GAMES_WORD"])
        let change = try #require(Support.builder.gamesSubcategoriesChange(from: ["GAMES_WORD"], to: ["GAMES_TRIVIA", "GAMES_WORD"], secondary: true))
        let shown = Support.builder.general(values, with: [change])
        #expect(shown.secondaryGamesSubcategories == ["GAMES_TRIVIA", "GAMES_WORD"])
        #expect(shown.gamesSubcategories.isEmpty)
        #expect(shown.isSecondaryGame)
        #expect(!shown.isGame)
    }

    @Test func theLoaderReadsBothPairs() throws {
        let json = Data(#"""
        {"type":"appInfos","id":"info-next","attributes":{"state":"PREPARE_FOR_SUBMISSION"},
         "relationships":{"primaryCategory":{"data":{"type":"appCategories","id":"GAMES"}},
         "primarySubcategoryOne":{"data":{"type":"appCategories","id":"GAMES_PUZZLE"}},
         "secondaryCategory":{"data":{"type":"appCategories","id":"GAMES"}},
         "secondarySubcategoryOne":{"data":{"type":"appCategories","id":"GAMES_WORD"}},
         "secondarySubcategoryTwo":{"data":{"type":"appCategories","id":"GAMES_TRIVIA"}}}}
        """#.utf8)
        let resource = try JSONDecoder().decode(AppInformationResourceDocument<AppInfoRatingAttributes>.Resource.self, from: json)
        let general = AppInformationContentLoader.general(appInfo: resource, app: nil, release: nil)
        #expect(general.gamesSubcategories == ["GAMES_PUZZLE"])
        #expect(general.secondaryGamesSubcategories == ["GAMES_WORD", "GAMES_TRIVIA"])
    }

    // MARK: - Suggestion field and slot

    @Test func theFieldIsPickedOnGeneralForTheApp() {
        let field = AppInformationSuggestionField.secondaryGamesSubcategories
        #expect(field.rawValue == "secondaryGamesSubcategories")
        #expect(field.page == .general)
        #expect(!field.isVersionLevel)
        #expect(field.isPicked)
        #expect(field.title == "Secondary Games Subcategories")
        #expect(field.normalized("Word, puzzle") == "GAMES_WORD,GAMES_PUZZLE")
        #expect(field.normalized("Productivity") == nil)
        #expect(field.displayValue("GAMES_WORD") == "Word")
        #expect(field.value(general: GeneralValues(secondaryGamesSubcategories: ["GAMES_WORD", "GAMES_PUZZLE"]), review: nil) == "GAMES_WORD,GAMES_PUZZLE")
    }

    @Test func theSlotNeedsGamesAsTheSecondaryCategory() throws {
        let lumen = DebugAppInformationContent.lumen(versionID: nil)
        #expect(!slots(lumen).canSuggest(.field(.secondaryGamesSubcategories)))
        #expect(slots(lumen).change(.field(.secondaryGamesSubcategories), to: "GAMES_WORD", source: claude) == nil)

        var game = lumen
        game.general.secondaryCategory = "GAMES"
        game.general.secondaryGamesSubcategories = ["GAMES_WORD"]
        let values = slots(game)
        #expect(values.canSuggest(.field(.secondaryGamesSubcategories)))
        #expect(!values.canSuggest(.field(.gamesSubcategories)), "The primary category isn't Games.")
        #expect(values.value(.field(.secondaryGamesSubcategories)) == "GAMES_WORD")
        let written = try #require(values.change(.field(.secondaryGamesSubcategories), to: "GAMES_WORD,GAMES_TRIVIA", source: claude))
        let change = try #require(written.change)
        #expect(written.id == change.id)
        #expect(change.source == claude)
        let after = slots(game, [change])
        #expect(after.value(.field(.secondaryGamesSubcategories)) == "GAMES_WORD,GAMES_TRIVIA")
        #expect(after.isPending(.field(.secondaryGamesSubcategories)))
        #expect(after.liveValue(.field(.secondaryGamesSubcategories)) == "GAMES_WORD")
    }

    private func slots(_ content: AppInformationContent, _ changes: [PendingChange] = []) -> AppInformationSlotValues {
        let builder = AppInformationChangeBuilder(appID: DebugFixtures.AppID.lumen, ids: content.ids, versionString: content.version?.versionString)
        return AppInformationSlotValues(content: content, accessibility: nil, builder: builder, changes: changes)
    }

    // MARK: - The page

    @Test func pickingThemUnderTheSecondaryCategory() async {
        let queue = ChangeQueue()
        let viewModel = AppInformationViewModel(app: app, services: DebugAppInformationServices(), queue: queue, suggestions: FieldSuggestionStore())
        await viewModel.load()
        viewModel.setSecondaryCategory("GAMES")
        #expect(viewModel.general?.isSecondaryGame == true)
        viewModel.setGamesSubcategory("GAMES_WORD", at: 0, secondary: true)
        viewModel.setGamesSubcategory("GAMES_PUZZLE", at: 1, secondary: true)
        #expect(viewModel.general?.secondaryGamesSubcategories == ["GAMES_WORD", "GAMES_PUZZLE"])
        #expect(viewModel.general?.gamesSubcategories.isEmpty == true)
        let id = viewModel.builder.changeID(.general, Key.secondaryGamesSubcategories)
        #expect(queue.change(id: id) != nil)

        // Another secondary category takes them away, as it does on App Store Connect.
        viewModel.setSecondaryCategory("BOOKS")
        #expect(viewModel.general?.secondaryGamesSubcategories.isEmpty == true)
        #expect(queue.change(id: id) == nil)
    }
}
#endif
