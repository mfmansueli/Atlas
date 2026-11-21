//
//  ProductPageChangeBuilderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What Review & Push sends for custom product pages, checked against App
/// Store Connect API 4.6: `AppCustomProductPageCreateRequest` (a page with
/// its first version inline, a template or inline languages), the
/// localization writes, and `AppCustomProductPageUpdateRequest`.
@MainActor
@Suite("ProductPageChangeBuilder")
struct ProductPageChangeBuilderTests {
    typealias Sample = DebugProductPagesData

    private let builder = ProductPageChangeBuilder(appID: Sample.appID)

    private static func object(_ value: Any?) throws -> [String: Any] {
        guard let object = value as? [String: Any] else { throw ProductPagesTestError.notJSON }
        return object
    }

    private static func body(_ request: PushRequest) throws -> [String: Any] {
        guard let body = request.body else { throw ProductPagesTestError.notJSON }
        return try object(JSONSerialization.jsonObject(with: body))
    }

    // MARK: - New pages

    /// From the default page of 1.4: that version is the template, and the
    /// version still lists the draft's languages, each with its text (App
    /// Store Connect requires `appCustomProductPageLocalizations`).
    @Test func aPageFromTheDefaultPageNamesTheVersionAsItsTemplate() throws {
        let document = ProductPageChangeBuilder.createDocument(Sample.privateDiary, appID: Sample.appID, templateVersionID: "6450200014")
        let data = try Self.object(document["data"])
        #expect(data["type"] as? String == "appCustomProductPages")
        #expect(try Self.object(data["attributes"])["name"] as? String == "Private diary")
        let relationships = try Self.object(data["relationships"])
        #expect(try Self.object(Self.object(relationships["app"])["data"])["id"] as? String == Sample.appID)
        #expect(try Self.object(Self.object(relationships["appStoreVersionTemplate"])["data"])["id"] as? String == "6450200014")
        #expect(relationships["customProductPageTemplate"] == nil)
        let included = try #require(document["included"] as? [[String: Any]])
        #expect(included.count == 1 + Sample.privateDiary.locales.count)
        #expect(included[0]["type"] as? String == "appCustomProductPageVersions")
        let listed = try #require(
            (Self.object(Self.object(included[0]["relationships"])["appCustomProductPageLocalizations"])["data"]) as? [[String: String]]
        )
        #expect(listed.count == Sample.privateDiary.locales.count)
        #expect(try Self.object(included[1]["attributes"])["promotionalText"] as? String == Sample.privateDiary.promotionalTexts["en-US"])
        #expect(try Self.object(included[0]["attributes"])["deepLink"] as? String == "https://lumen.app/lock")
    }

    /// An empty page makes its languages inline, each with its text.
    @Test func anEmptyPageMakesItsLanguagesInline() throws {
        var draft = Sample.privateDiary
        draft.start = .empty
        let document = ProductPageChangeBuilder.createDocument(draft, appID: Sample.appID, templateVersionID: "6450200014")
        let relationships = try Self.object(Self.object(document["data"])["relationships"])
        #expect(relationships["appStoreVersionTemplate"] == nil)
        let included = try #require(document["included"] as? [[String: Any]])
        #expect(included.count == 5)
        let listed = try #require(
            (Self.object(Self.object(included[0]["relationships"])["appCustomProductPageLocalizations"])["data"]) as? [[String: String]]
        )
        #expect(listed.map { $0["id"] } == ["${l1}", "${l2}", "${l3}", "${l4}"])
        let english = try Self.object(included[1]["attributes"])
        #expect(english["locale"] as? String == "en-US")
        #expect(english["promotionalText"] as? String == Sample.privateDiary.promotionalTexts["en-US"])
        #expect(try Self.object(included[2]["attributes"])["promotionalText"] == nil)
        // App Store Connect refuses an inline ID in the link back.
        #expect(included[1]["relationships"] == nil)
    }

    /// Every start makes the draft's languages inline.
    @Test func whichLanguagesAreMadeInline() {
        var draft = Sample.privateDiary
        #expect(ProductPageChangeBuilder.inlineLocales(draft, templateVersionID: "v") == draft.locales)
        #expect(ProductPageChangeBuilder.inlineLocales(draft, templateVersionID: nil) == draft.locales)
        draft.start = .copy(pageID: Sample.PageID.prompts, name: "Prompts")
        #expect(ProductPageChangeBuilder.inlineLocales(draft, templateVersionID: nil) == draft.locales)
        draft.start = .empty
        #expect(ProductPageChangeBuilder.inlineLocales(draft, templateVersionID: "v") == draft.locales)
    }

    @Test func aCopyNamesThePageItCopies() throws {
        var draft = Sample.privateDiary
        draft.start = .copy(pageID: Sample.PageID.prompts, name: "Prompts")
        let document = ProductPageChangeBuilder.createDocument(draft, appID: Sample.appID, templateVersionID: "6450200014")
        let relationships = try Self.object(Self.object(document["data"])["relationships"])
        #expect(try Self.object(Self.object(relationships["customProductPageTemplate"])["data"])["id"] as? String == Sample.PageID.prompts)
        #expect(relationships["appStoreVersionTemplate"] == nil)
    }

    /// The create request, then each language's text and keywords written
    /// into the page it made; a language made inline already has its text.
    @Test func theNewPageChangeWritesEachLanguageIntoTheCreatedPage() throws {
        let change = try #require(builder.newPageChange(Sample.privateDiary, defaultPage: Sample.defaultPage))
        #expect(change.id == builder.newPageChangeID(draftID: Sample.PageID.privateDiary))
        #expect(change.requests.first?.method == .post)
        #expect(change.requests.first?.path == "/v1/appCustomProductPages")
        // Texts are made inline; only keywords are written after.
        let writes = change.requests.dropFirst().compactMap(ProductPageLocaleWrite.init)
        let withKeywords = Sample.privateDiary.locales.filter { !(Sample.privateDiary.keywords[$0] ?? []).isEmpty }
        #expect(writes.map(\.content.locale) == withKeywords)
        #expect(writes.allSatisfy { $0.pageID == ProductPageChangeBuilder.createdPage })
        #expect(writes.allSatisfy { $0.content.promotionalText == nil })
        #expect(writes.first { $0.content.locale == "de-DE" }?.content.addKeywords == ["privat", "tagebuch", "sperre"])
        #expect(change.blockedReason == nil)

        var empty = Sample.privateDiary
        empty.start = .empty
        let inline = try #require(builder.newPageChange(empty, defaultPage: Sample.defaultPage))
        let inlineWrites = inline.requests.dropFirst().compactMap(ProductPageLocaleWrite.init)
        #expect(inlineWrites.first?.content.promotionalText == nil)
        #expect(inlineWrites.first?.content.addKeywords == ["private", "diary", "lock"])
    }

    @Test func aCopyOfADraftWaitsUntilThatPageIsPushed() {
        var draft = Sample.privateDiary
        draft.start = .copy(pageID: "draft-evening", name: "Evening prompts")
        #expect(ProductPageChangeBuilder.problem(of: draft) == "“Evening prompts” isn’t in App Store Connect yet, so it can’t be copied. Push it first.")
        draft.start = .copy(pageID: Sample.PageID.prompts, name: "Prompts")
        #expect(ProductPageChangeBuilder.problem(of: draft) == nil)
        draft.name = "  "
        #expect(ProductPageChangeBuilder.problem(of: draft) == "A page needs a name.")
    }

    // MARK: - Changes to a page

    @Test func aTextChangeWritesTheLanguageAndCanBeRestored() throws {
        let prompts = try #require(Sample.pages.first { $0.id == Sample.PageID.prompts })
        #expect(builder.textChange(prompts.localization("en-US")?.promotionalText ?? "", locale: "en-US", of: prompts, source: .you) == nil)
        let change = try #require(builder.textChange("Start with one line.", locale: "en-US", of: prompts, source: .you))
        #expect(change.id == "productPages.\(Sample.appID).\(Sample.PageID.prompts).en-US.promotionalText")
        let write = try #require(change.requests.first.flatMap(ProductPageLocaleWrite.init))
        #expect(write.content.promotionalText == "Start with one line.")
        #expect(write.content.currentDeepLink == "https://lumen.app/prompts/today")
        let restore = try #require(change.restoreRequests.first.flatMap(ProductPageLocaleWrite.init))
        #expect(restore.content.promotionalText == prompts.localization("en-US")?.promotionalText)
    }

    @Test func aKeywordsChangeAddsAndRemovesWords() throws {
        let prompts = try #require(Sample.pages.first { $0.id == Sample.PageID.prompts })
        #expect(builder.keywordsChange(["daily", "journal", "prompts"], locale: "en-US", of: prompts, source: .you) == nil)
        let change = try #require(builder.keywordsChange(["journal", "prompts", "reflection"], locale: "en-US", of: prompts, source: .you))
        let write = try #require(change.requests.first.flatMap(ProductPageLocaleWrite.init))
        #expect(write.content.addKeywords == ["reflection"])
        #expect(write.content.removeKeywords == ["daily"])
        let restore = try #require(change.restoreRequests.first.flatMap(ProductPageLocaleWrite.init))
        #expect(restore.content.addKeywords == ["daily"])
        #expect(restore.content.removeKeywords == ["reflection"])
    }

    /// `AppCustomProductPageUpdateRequest`: only `name` and `visible`.
    @Test func visibleIsAPatchOfThePage() throws {
        let prompts = try #require(Sample.pages.first { $0.id == Sample.PageID.prompts })
        #expect(builder.visibleChange(true, of: prompts, source: .you) == nil)
        let change = try #require(builder.visibleChange(false, of: prompts, source: .you))
        let request = try #require(change.requests.first)
        #expect(request.method == .patch)
        #expect(request.path == "/v1/appCustomProductPages/\(Sample.PageID.prompts)")
        let data = try Self.object(Self.body(request)["data"])
        #expect(data["type"] as? String == "appCustomProductPages")
        #expect(data["id"] as? String == Sample.PageID.prompts)
        #expect(try Self.object(data["attributes"])["visible"] as? Bool == false)
        let restore = try Self.object(Self.body(#require(change.restoreRequests.first))["data"])
        #expect(try Self.object(restore["attributes"])["visible"] as? Bool == true)
    }

    @Test func deletingIsADeleteOfThePage() throws {
        let year = try #require(Sample.pages.first { $0.id == Sample.PageID.year })
        let change = builder.deleteChange(of: year)
        #expect(change.requests == [PushRequest(method: .delete, path: "/v1/appCustomProductPages/\(Sample.PageID.year)")])
        #expect(change.group == "Custom Product Pages · Year in review")
        #expect(builder.edits(for: Sample.PageID.year, in: [change]).isDeleted)
    }
}
