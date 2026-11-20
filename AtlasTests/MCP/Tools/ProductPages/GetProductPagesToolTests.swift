//
//  GetProductPagesToolTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// `get_product_pages`: the default page and every custom one as the
/// section shows them, with the keywords still free, the numbers, the
/// suggestions and what's queued.
@MainActor
@Suite("get_product_pages")
struct GetProductPagesToolTests {
    typealias PageID = MCPProductPagesFixtures.PageID

    private let fixtures = MCPProductPagesFixtures()

    @Test func theToolsAreInTheToolboxFreeAndInTheInstructions() {
        let names: Set = ["get_product_pages", "propose_product_page", "propose_product_page_texts"]
        #expect(MCPToolbox.standard.toolNames.isSuperset(of: names))
        #expect(names.compactMap { ProAssistantGate.refusal(forTool: $0, isPro: false) }.isEmpty)
        #expect(GetProductPagesTool().definition.isReadOnly)
        #expect(ProposeProductPageTool().definition.proposalKind == .storeText)
        #expect(ProposeProductPageTextsTool().definition.proposalKind == .storeText)
        for name in names {
            #expect(MCPEndpoint.instructions.contains(name))
        }
        #expect(MCPEndpoint.instructions.contains("pushing, submitting and making a page visible are theirs"))
    }

    @Test func thePagesAreReadWithTheirLimitKeywordsAndDefaultPage() async throws {
        let outcome = try await fixtures.call(fixtures.getTool, ["appId": "Lumen Journal"])
        let result = outcome.result
        #expect(outcome.isError == false)
        #expect(outcome.logLines.first?.outcome == MCPCallOutcome.read)
        #expect(result["pageLimit"] == ["pages": 6, "limit": 70, "suggestedPagesWaiting": 2, "roomFor": 62])
        #expect(result["limits"]?["promotionalText"] == 170)
        #expect(result["primaryLanguage"] == "en-US")
        #expect(result["defaultPage"]?["approvedVersion"] == "1.3")
        #expect(result["defaultPage"]?["startsFromVersion"] == "1.4")
        #expect(result["defaultPage"]?["promotionalText"]?["de-DE"]?.stringValue?.hasPrefix("Schreib jeden Tag") == true)
        // A keyword leads to one page: the draft's count as taken too.
        #expect(result["keywords"]?["en-US"]?["free"] == ["gratitude", "reflection"])
        #expect(result["keywords"]?["en-US"]?["usedBy"]?["mood"] == "Mood tracking")
        #expect(result["keywords"]?["en-US"]?["usedBy"]?["lock"] == "Private diary")
        #expect(result["keywords"]?["de-DE"]?["free"]?.arrayValue?.contains("dankbarkeit") == true)
        let names = result["pages"]?.arrayValue?.compactMap { $0["name"]?.stringValue }
        #expect(names == ["Prompts", "Mood tracking", "Sleep & wind-down", "Year in review", "Therapists", "Private diary"])
        #expect(result["textRules"]?.arrayValue?.isEmpty == false)
        #expect(result["next"]?.stringValue?.contains("propose_product_page") == true)
        #expect(result["textsLeftOut"] == nil)
    }

    @Test func eachPageHasItsLanguagesNumbersAndWhetherItTakesTexts() async throws {
        let result = try await fixtures.call(fixtures.getTool, ["appId": "Lumen Journal"]).result
        let prompts = try fixtures.page("Prompts", in: result)
        #expect(prompts["id"] == .string(PageID.prompts))
        #expect(prompts["state"] == "APPROVED")
        #expect(prompts["visible"] == true)
        #expect(prompts["url"]?.stringValue?.contains("ppid=\(PageID.prompts)") == true)
        #expect(prompts["deepLink"] == "https://lumen.app/prompts/today")
        #expect(prompts["languages"]?["en-US"]?["promotionalText"]?.stringValue?.hasPrefix("A new prompt every evening") == true)
        #expect(prompts["languages"]?["en-US"]?["keywords"] == ["journal", "prompts", "daily"])
        #expect(prompts["languages"]?["en-US"]?["ownScreenshots"] == true)
        #expect(prompts["languages"]?["de-DE"]?["textFromDefault"] == true)
        #expect(prompts["showsDefaultIn"]?.arrayValue?.contains("ja") == true)
        #expect(prompts["numbers"]?["impressions"] == 18400)
        #expect(prompts["numbers"]?["downloadRate"] == .double(32.4))
        #expect(prompts["numbers"]?["vsDefault"] == ["result": "aboutTheSame"])
        // Approved: a suggestion shows once the person presses Edit….
        #expect(prompts["takesTexts"] == true)
        #expect(prompts["newVersionNote"]?.stringValue?.contains("version 2") == true)

        let mood = try fixtures.page("Mood tracking", in: result)
        #expect(mood["numbers"]?["vsDefault"] == ["result": "below", "points": .double(6.1)])

        let sleep = try fixtures.page("Sleep & wind-down", in: result)
        #expect(sleep["newVersion"] == ["number": 2, "state": "IN_REVIEW"])
        #expect(sleep["takesTexts"] == false)
        #expect(sleep["why"]?.stringValue?.contains("App Review") == true)
        // 96 views: no rate to quote.
        #expect(sleep["numbers"]?["vsDefault"] == ["result": "tooFewToCompare", "pageViews": 96, "needs": 200])
        #expect(sleep["numbers"]?["downloadRate"] == nil)

        #expect(try fixtures.page("Therapists", in: result)["numbers"] == "Hidden, so nobody sees it")
        #expect(try fixtures.page("Year in review", in: result)["state"] == "REJECTED")

        let diary = try fixtures.page("Private diary", in: result)
        #expect(diary["state"] == "draft")
        #expect(diary["visible"] == false)
        #expect(diary["url"] == nil)
        #expect(diary["numbers"] == nil)
        #expect(diary["draft"]?["changeId"] == .string(fixtures.builder.newPageChangeID(draftID: PageID.privateDiary)))
        #expect(diary["draft"]?["startsFrom"] == "defaultPage")
        #expect(diary["languages"]?["en-US"]?["keywords"] == ["private", "diary", "lock"])
        #expect(diary["takesTexts"] == true)

        #expect(result["defaultPage"]?["numbers"]?["downloadRate"] == .double(31.7))
        #expect(result["numbersPeriod"]?["through"] == "2026-11-09")
        #expect(result["numbersPeriod"]?["days"] == 28)
    }

    @Test func suggestionsAreListedWithTheirStatus() async throws {
        fixtures.store.dismiss("grat", for: MCPProductPagesFixtures.appID)
        fixtures.store.add([DebugProductPagesData.refusedSuggestion], for: MCPProductPagesFixtures.appID)
        let suggestions = try #require(try await fixtures.call(fixtures.getTool, ["appId": "Lumen Journal"]).result["suggestions"])

        let pages = try #require(suggestions["pages"]?.arrayValue)
        #expect(pages.compactMap { $0["id"]?.stringValue } == ["weekly", "grat"])
        #expect(pages[0]["status"] == "open")
        #expect(pages[0]["by"] == "Claude Code")
        #expect(pages[0]["evidence"] == [["source": "analytics", "detail": "Product Page test"]])
        #expect(pages[0]["keywords"]?["en-US"] == ["reflection", "habit", "mindful"])
        // Empty languages aren't texts.
        #expect(pages[0]["promotionalText"]?.objectValue?.keys.sorted() == ["en-US"])
        #expect(pages[0]["startFrom"] == "defaultPage")
        #expect(pages[1]["status"] == "dismissed")
        #expect(pages[1]["audience"] == nil)

        let texts = try #require(suggestions["texts"]?.arrayValue)
        #expect(texts.compactMap { $0["locale"]?.stringValue } == ["de-DE", "ja", "en-US"])
        #expect(texts[0]["status"] == "open")
        #expect(texts[0]["page"] == "Private diary")
        #expect(texts[0]["reason"]?.stringValue?.contains("gesperrt") == true)
        #expect(texts[2]["status"] == "notOffered")
        #expect(texts[2]["why"]?.stringValue?.isEmpty == false)
    }

    @Test func queuedEditsAreShownAndAPageQueuedForDeletionIsGone() async throws {
        let snapshot = DebugProductPagesData.snapshot
        let prompts = try #require(snapshot.pages.first { $0.id == PageID.prompts })
        let mood = try #require(snapshot.pages.first { $0.id == PageID.mood })
        let therapists = try #require(snapshot.pages.first { $0.id == PageID.therapists })
        let builder = fixtures.builder
        let text = try #require(builder.textChange("Ein neuer Impuls jeden Abend.", locale: "de-DE", of: prompts, source: .you))
        let keywords = try #require(builder.keywordsChange(["mood"], locale: "en-US", of: mood, source: .you))
        fixtures.changes.upsert(contentsOf: [text, keywords, builder.deleteChange(of: therapists)])
        let result = try await fixtures.call(fixtures.getTool, ["appId": "Lumen Journal"]).result
        let queued = try fixtures.page("Prompts", in: result)["queued"]
        #expect(queued?["promotionalText"]?["de-DE"] == "Ein neuer Impuls jeden Abend.")
        #expect(queued?["changes"] == 1)
        // Mood tracking lets go of “habit”: it's free again.
        #expect(result["keywords"]?["en-US"]?["free"] == ["gratitude", "reflection", "habit"])
        #expect(result["pages"]?.arrayValue?.contains { $0["name"] == "Therapists" } == false)
        #expect(result["pageLimit"]?["pages"] == 5)
        // An approved page with edits queued takes texts without Edit….
        #expect(try fixtures.page("Prompts", in: result)["newVersionNote"] == nil)
    }

    @Test func onePageIsReadWholeAndAnUnknownOneIsNotFound() async throws {
        let result = try await fixtures.call(fixtures.getTool, ["appId": "Lumen Journal", "pageId": .string(PageID.privateDiary)]).result
        #expect(result["pages"]?.arrayValue?.count == 1)
        #expect(result["suggestions"]?["texts"]?.arrayValue?.count == 2)
        await #expect(throws: MCPToolError.self) {
            try await fixtures.call(fixtures.getTool, ["appId": "Lumen Journal", "pageId": "nope"])
        }
    }

    @Test func withoutAnalyticsTheNumbersAreLeftOutAndSaidSo() async throws {
        var fixtures = fixtures
        fixtures.analytics = AnalyticsStore()
        let result = try await fixtures.call(fixtures.getTool, ["appId": "Lumen Journal"]).result
        #expect(result["numbersNote"]?.stringValue?.contains("no product page numbers") == true)
        #expect(result["numbersPeriod"] == nil)
        #expect(result["pages"]?.arrayValue?.allSatisfy { $0["numbers"] == nil } == true)
    }

    @Test func nextPointsToTheSplitThatHasNumbers() async throws {
        // Prompts has numbers: compare the pages.
        let withPages = try await fixtures.call(fixtures.getTool, ["appId": "Lumen Journal"]).result["next"]?.stringValue ?? ""
        #expect(withPages.contains("Compare the pages with get_analytics_breakdown by productPage"))
        #expect(withPages.contains("first three screenshots, not its text"))
        // None has: look for audiences by source and by market.
        var fixtures = fixtures
        fixtures.analytics = AnalyticsStore()
        let withoutNumbers = try await fixtures.call(fixtures.getTool, ["appId": "Lumen Journal"]).result["next"]?.stringValue ?? ""
        #expect(withoutNumbers.contains("No custom page has numbers yet"))
        #expect(withoutNumbers.contains("by source"))
    }

    @Test func aPageShowsItsBriefAndWhetherItsScreenshotsWereAdded() async throws {
        let brief = ProductPageBrief(audience: "People who track their mood", screens: "Mood first", source: "Claude Code")
        fixtures.store.saveBrief(brief, pageName: "Mood tracking", for: MCPProductPagesFixtures.appID)
        fixtures.store.saveBrief(brief, pageName: "Prompts", for: MCPProductPagesFixtures.appID)
        let result = try await fixtures.call(fixtures.getTool, ["appId": "Lumen Journal"]).result
        let mood = try fixtures.page("Mood tracking", in: result)
        #expect(mood["brief"]?["screens"] == "Mood first")
        #expect(mood["brief"]?["audience"] == "People who track their mood")
        #expect(mood["brief"]?["by"] == "Claude Code")
        #expect(mood["brief"]?["screenshotsAdded"] == false)
        #expect(try fixtures.page("Prompts", in: result)["brief"]?["screenshotsAdded"] == true)
        #expect(try fixtures.page("Year in review", in: result)["brief"] == nil)
    }

    @Test func withoutAnApprovedVersionNoKeywordsCanBeChosen() async throws {
        var fixtures = fixtures
        fixtures.services = DebugProductPagesServices(hasNoApprovedVersion: true)
        let result = try await fixtures.call(fixtures.getTool, ["appId": "Lumen Journal"]).result
        #expect(result["keywords"] == [:])
        #expect(result["defaultPage"]?["approvedVersion"] == .null)
        #expect(result["next"]?.stringValue?.contains("No version is approved yet") == true)
    }

    @Test func atTheLimitNextSaysNoMorePages() async throws {
        var fixtures = fixtures
        fixtures.services = DebugProductPagesServices(isAtLimit: true)
        let result = try await fixtures.call(fixtures.getTool, ["appId": "Lumen Journal"]).result
        #expect(result["pageLimit"]?["pages"] == 70)
        #expect(result["pageLimit"]?["roomFor"] == 0)
        #expect(result["next"]?.stringValue?.contains("70 of 70") == true)
        // Past 20 pages the list leaves the texts out; pageId reads one.
        #expect(result["textsLeftOut"] != nil)
        #expect(try fixtures.page("Prompts", in: result)["languages"]?["en-US"]?["ownText"] == true)
    }

    @Test func aFailedReadSaysWhy() async throws {
        var fixtures = fixtures
        fixtures.services = DebugProductPagesServices(error: .rateLimited)
        await #expect(throws: MCPToolError.self) {
            try await fixtures.call(fixtures.getTool, ["appId": "Lumen Journal"])
        }
    }
}
#endif
