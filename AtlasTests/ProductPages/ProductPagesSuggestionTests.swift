//
//  ProductPagesSuggestionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Board 53's suggested pages and the editor's suggested texts: where a
/// suggested page starts from, the evidence and the texts Atlas stopped.
@MainActor
@Suite("Custom Product Pages suggestions")
struct ProductPagesSuggestionTests {
    typealias Sample = DebugProductPagesData

    private func model(with suggestion: ProductPageSuggestion) async -> ProductPagesViewModel {
        var archive = Sample.archive()
        archive.pageSuggestions = [suggestion]
        return await ProductPagesTestModel.make(store: Sample.store(archive))
    }

    private func acceptedDraft(_ model: ProductPagesViewModel, named name: String) -> ProductPageDraft? {
        model.store.drafts(for: Sample.appID).first { $0.name == name }
    }

    @Test func aSuggestedPageStartsFromTheDefaultPageUnlessItSaysOtherwise() async throws {
        let weekly = try #require(Sample.pageSuggestions.first)
        let model = await model(with: weekly)
        model.acceptPage(weekly)
        #expect(acceptedDraft(model, named: "Weekly reflections")?.start == .defaultPage)
        #expect(model.pageSuggestions.isEmpty)
    }

    @Test(arguments: [
        ProductPageStart.empty, ProductPageStart.copy(pageID: DebugProductPagesData.PageID.prompts, name: "Prompts"),
    ])
    func aSuggestedPageKeepsItsStartingPoint(_ start: ProductPageStart) async throws {
        var weekly = try #require(Sample.pageSuggestions.first)
        weekly.start = start
        let model = await model(with: weekly)
        model.acceptPage(weekly)
        let draft = try #require(acceptedDraft(model, named: "Weekly reflections"))
        #expect(draft.start == start)
        let change = try #require(model.queue.change(id: model.builder.newPageChangeID(draftID: draft.id)))
        #expect(change.blockedReason == nil)
    }

    @Test func aTextSuggestionsEvidenceIsItsPill() throws {
        let german = try #require(Sample.textSuggestions.first { $0.locale == "de-DE" })
        #expect(german.evidenceTitle == "Reviews · German reviews")
        var japanese = try #require(Sample.textSuggestions.first { $0.locale == "ja" })
        #expect(japanese.evidenceTitle == nil)
        japanese.evidence = []
        #expect(japanese.evidenceTitle == nil)
        japanese.evidence = [SuggestionEvidence(kind: "analytics", ref: "")]
        #expect(japanese.evidenceTitle == "Analytics")
    }

    @Test func eachPieceOfEvidenceIsItsOwnPillAndKeywordsListTheirLanguages() throws {
        var page = try #require(Sample.pageSuggestions.first { $0.id == "grat" })
        page.evidence = [
            SuggestionEvidence(kind: "analytics", ref: "Brazil: 4% open the page"), SuggestionEvidence(kind: "keywords", ref: ""),
        ]
        #expect(page.evidenceTitles == ["Analytics · Brazil: 4% open the page", "Keywords"])
        #expect(page.evidenceTitle == "Analytics · Brazil: 4% open the page · Keywords")

        // A page for other markets: the primary language has none.
        page.keywords = ["pt-BR": ["bom dia"], "es-MX": ["buenos días"], "ja": []]
        #expect(page.keywordLocales(primary: "en-US") == ["es-MX", "pt-BR"])
        page.keywords["en-US"] = ["morning"]
        #expect(page.keywordLocales(primary: "en-US") == ["en-US", "es-MX", "pt-BR"])
    }

    @Test func aSuggestedPageKeepsTheTextsAtlasStopped() throws {
        let gratitude = try #require(Sample.pageSuggestions.first { $0.id == "grat" })
        let refused = try #require(gratitude.notOfferedTexts?.first)
        #expect(refused.isRefused)
        #expect(refused.locale == "de-DE")
        #expect(refused.refusedPhrases.contains { $0.localizedCaseInsensitiveContains("kostenlos") })
        // It isn't in what accepting writes.
        #expect(gratitude.promotionalTexts["de-DE"]?.isEmpty != false)
    }

    @Test func askingForAnotherTextOfASuggestedPageSendsThePageAgain() async throws {
        let gratitude = try #require(Sample.pageSuggestions.first { $0.id == "grat" })
        let refused = try #require(gratitude.notOfferedTexts?.first)
        let model = await ProductPagesTestModel.make()
        let prompt = model.askForAnotherPrompt(refused, in: gratitude)
        #expect(prompt.contains("propose_product_page"))
        #expect(prompt.contains("“Gratitude journal”"))
        #expect(prompt.contains(refused.refusal))
        #expect(model.askForAnotherPrompt(Sample.refusedSuggestion).contains("propose_product_page_texts"))
        #expect(model.suggestPagesPrompt.contains("keywords.<locale>.free"))
    }

    @Test func suggestPagesLooksForAudiencesBySourceAndMarketAndLeadsWithScreenshots() async {
        let prompt = await ProductPagesTestModel.make().suggestPagesPrompt
        #expect(prompt.contains("get_analytics_breakdown by source"))
        #expect(prompt.contains("by language and by territory"))
        #expect(prompt.contains("by productPage once pages have numbers"))
        #expect(prompt.contains("first three screenshots, not its text"))
        #expect(prompt.contains("version 1.3’s keywords"))
        #expect(prompt.contains("send it again under the same name"))
        #expect(prompt.contains("Don't push or submit anything"))
    }

    @Test func anAcceptedSuggestionLeavesItsBriefUntilTheDraftIsDeleted() async throws {
        let weekly = try #require(Sample.pageSuggestions.first)
        let model = await model(with: weekly)
        model.acceptPage(weekly)
        let draft = try #require(acceptedDraft(model, named: "Weekly reflections"))
        let brief = try #require(model.brief(of: ProductPagesTestModel.page(model, draft.id)))
        #expect(brief == ProductPageBrief(audience: weekly.audience, screens: weekly.screens, source: "Claude Code"))
        // Kept by name, so the page App Store Connect makes of it has it too.
        #expect(model.store.archive(for: Sample.appID).brief(named: " weekly Reflections") == brief)

        model.delete(draft.id)
        #expect(model.store.archive(for: Sample.appID).brief(named: "Weekly reflections") == nil)
        model.undoLast()
        #expect(model.store.archive(for: Sample.appID).brief(named: "Weekly reflections") == brief)
    }

    @Test func aSuggestionWithoutScreensLeavesNoBrief() async throws {
        var weekly = try #require(Sample.pageSuggestions.first)
        weekly.screens = ""
        let model = await model(with: weekly)
        model.acceptPage(weekly)
        let draft = try #require(acceptedDraft(model, named: "Weekly reflections"))
        #expect(try model.brief(of: ProductPagesTestModel.page(model, draft.id)) == nil)
    }

    @Test func theEditorShowsTheLanguagesSuggestionOrTheStoppedText() async throws {
        var archive = Sample.archive()
        archive.textSuggestions.append(Sample.refusedSuggestion)
        let model = await ProductPagesTestModel.make(store: Sample.store(archive))
        model.open(Sample.PageID.privateDiary)
        model.localeCode = "de-DE"
        #expect(model.textSuggestion?.isRefused == false)
        model.localeCode = "en-US"
        #expect(model.textSuggestion?.isRefused == true)
        let page = try ProductPagesTestModel.page(model, Sample.PageID.privateDiary)
        #expect(model.acceptableTextSuggestions(of: page).map(\.locale).sorted() == ["de-DE", "ja"])
    }

    /// One language picker, not a chip per language (README-DS §12): a
    /// suggested text is one suggestion to review; the languages showing
    /// the default page's content are listed last.
    @Test func theLanguageBarCountsTheSuggestedTexts() async throws {
        let model = await ProductPagesTestModel.make()
        model.open(Sample.PageID.privateDiary)
        model.localeCode = "de-DE"
        let page = try ProductPagesTestModel.page(model, Sample.PageID.privateDiary)
        let bar = try #require(model.languageBarModel(of: page))
        #expect(bar.current.code == "de-DE")
        #expect(bar.hereText == "1 suggestion here")
        #expect(bar.totalCount == 2)
        #expect(bar.restText == "1 more in 1 other language")
        #expect(bar.menuAcceptAllTitle == "Accept All Languages", "It accepts at once, with Undo")
        let same = model.languages(of: page).filter { $0.state == .same }.map(\.code)
        #expect(bar.entries.filter(\.usesPrimary).map(\.locale.code) == same)
        if !same.isEmpty {
            #expect(bar.menuGroups(matching: "").last?.title == "Uses the default page")
        }
    }
}
