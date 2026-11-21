//
//  ProductPageCreatedDraftTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A draft App Store Connect made although its push didn't finish (on Alba
/// Apple answered after Atlas stopped waiting): the draft becomes that
/// page, so a retry can't make a second one, and what the page still needs
/// from the draft waits in Review & Push.
@MainActor
struct ProductPageCreatedDraftTests {
    typealias Sample = DebugProductPagesData
    typealias PageID = DebugProductPagesData.PageID

    @Test func aDraftAppleMadeBecomesThatPage() async throws {
        let services = FakeProductPagesServices()
        let queue = ChangeQueue(changes: Sample.pendingChanges)
        let model = await ProductPagesTestModel.make(services, queue: queue)
        model.open(PageID.privateDiary)
        let createID = model.builder.newPageChangeID(draftID: PageID.privateDiary)
        #expect(queue.change(id: createID) != nil)

        // The push timed out, but Apple made the page.
        services.pushPrivateDiary(.prepareForSubmission)
        await model.load(force: true)

        #expect(queue.change(id: createID) == nil)
        #expect(model.page(PageID.privateDiary) == nil)
        #expect(model.selectedPageID == PageID.privateDiaryPushed)
        let page = try ProductPagesTestModel.page(model, PageID.privateDiaryPushed)
        let brought = model.builder.changes(of: page.id, in: queue.changes)
        let draft = Sample.privateDiary
        let keywordLocales = draft.locales.filter { locale in
            let chosen = draft.keywords[locale] ?? []
            return !chosen.isEmpty && Set(chosen) != Set(page.localization(locale)?.keywords ?? [])
        }
        #expect(brought.filter { $0.id.hasSuffix(".keywords") }.count == keywordLocales.count)
        #expect(model.toast?.text == "“Private diary” is in App Store Connect. What it still needs from the draft is in Review & Push.")
    }

    /// A page by that name App Review already has isn't the one the push
    /// made: the draft stays as it is.
    @Test func aPageAlreadyInReviewIsNotTakenForTheDraft() async {
        let services = FakeProductPagesServices()
        let queue = ChangeQueue(changes: Sample.pendingChanges)
        let model = await ProductPagesTestModel.make(services, queue: queue)
        services.pushPrivateDiary(.waitingForReview)
        await model.load(force: true)
        #expect(queue.change(id: model.builder.newPageChangeID(draftID: PageID.privateDiary)) != nil)
    }
}
