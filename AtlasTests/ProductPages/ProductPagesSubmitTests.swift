//
//  ProductPagesSubmitTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Board 54: Push and Submit… through Review & Push, Submit for Review,
/// Cancel Submission, "Make the page visible when it's approved", and the
/// status banners.
@MainActor
@Suite("Custom Product Pages submit")
struct ProductPagesSubmitTests {
    typealias Sample = DebugProductPagesData
    typealias PageID = DebugProductPagesData.PageID

    /// Private diary pushed, its first version in `state`.
    private func pushedModel(
        _ state: ProductPageState, services: FakeProductPagesServices = FakeProductPagesServices(), store: ProductPagesStore = Sample.store()
    ) async -> ProductPagesViewModel {
        services.pushPrivateDiary(state)
        return await ProductPagesTestModel.make(services, store: store, queue: ChangeQueue())
    }

    @Test func aDraftIsPushedFirstThenSubmitForReviewOpens() async throws {
        let services = FakeProductPagesServices()
        let queue = ChangeQueue(changes: Sample.pendingChanges)
        let model = await ProductPagesTestModel.make(services, queue: queue)
        let draft = try ProductPagesTestModel.page(model, PageID.privateDiary)
        model.open(draft.id)
        #expect(model.primaryActionTitle(of: draft) == "Submit for Review…")
        #expect(model.submittableVersion(of: draft) == nil)
        #expect(model.pushAndSubmit(draft))
        #expect(model.submitsAfterPushPageName == "Private diary")
        #expect(!model.isSubmitPresented)

        // Review & Push made it.
        queue.discard(id: model.builder.newPageChangeID(draftID: PageID.privateDiary))
        services.pushPrivateDiary(.prepareForSubmission)
        await model.didPush()
        #expect(model.isSubmitPresented)
        #expect(model.selectedPageID == PageID.privateDiaryPushed)
        #expect(model.submitsAfterPushPageName == nil)
        let pushed = try ProductPagesTestModel.page(model, PageID.privateDiaryPushed)
        #expect(model.primaryActionTitle(of: pushed) == "Submit for Review…")
    }

    @Test func aPushTheKeyWasRefusedSaysTheKeyCantChangePages() async throws {
        let model = await ProductPagesTestModel.make()
        let refused = try #require(AppStoreConnectError.forbidden(detail: nil).errorDescription)
        await model.didPush(failures: [refused + " More."])
        #expect(model.keyCannotChange)
        #expect(!ProductPagesViewModel.isForbidden("The server is busy."))
    }

    @Test func submittingSendsTheVersionAndKeepsTheChoiceToMakeItVisible() async throws {
        let services = FakeProductPagesServices()
        let model = await pushedModel(.prepareForSubmission, services: services)
        let page = try ProductPagesTestModel.page(model, PageID.privateDiaryPushed)
        model.open(page.id)
        #expect(model.pushAndSubmit(page) == false)
        #expect(model.isSubmitPresented)
        await model.submit(page, makeVisible: true)
        #expect(services.submitted == ["private-v1"])
        #expect(!model.isSubmitPresented)
        let waiting = try ProductPagesTestModel.page(model, page.id)
        #expect(waiting.editing?.state == .waitingForReview)
        #expect(model.makesVisibleWhenApproved(waiting))
        #expect(model.toast?.text == "“Private diary” was submitted to App Review.")
        #expect(model.primaryActionTitle(of: waiting) == nil)
    }

    @Test func aRefusedSubmissionStaysOpenWithWhy() async throws {
        let services = FakeProductPagesServices()
        services.submitError = .forbidden(detail: nil)
        let model = await pushedModel(.prepareForSubmission, services: services)
        let page = try ProductPagesTestModel.page(model, PageID.privateDiaryPushed)
        model.isSubmitPresented = true
        await model.submit(page, makeVisible: false)
        #expect(model.isSubmitPresented)
        #expect(model.submitError != nil)
        #expect(model.keyCannotChange)
        #expect(services.submitted.isEmpty)
    }

    @Test func aWaitingPageCanBeTakenBack() async throws {
        let services = FakeProductPagesServices()
        let model = await pushedModel(.waitingForReview, services: services)
        let page = try ProductPagesTestModel.page(model, PageID.privateDiaryPushed)
        #expect(model.canCancelSubmission(of: page))
        #expect(model.statusNote(of: page)?.action == .cancelSubmission)
        #expect(model.statusNote(of: page)?.title == "Waiting for Review.")
        await model.cancelSubmission(of: page)
        #expect(services.cancelled == ["private-v1"])
        #expect(try ProductPagesTestModel.page(model, page.id).editing?.state == .prepareForSubmission)
        #expect(model.toast?.text == "Submission cancelled. The page is back to Prepare for Submission.")
    }

    @Test func withoutCancelTheWaitingBannerOnlySaysSo() async throws {
        let services = FakeProductPagesServices()
        services.cancels = false
        let model = await pushedModel(.waitingForReview, services: services)
        let page = try ProductPagesTestModel.page(model, PageID.privateDiaryPushed)
        #expect(!model.canCancelSubmission(of: page))
        #expect(model.statusNote(of: page)?.action == nil)
        #expect(model.statusNote(of: page)?.message == "App Review usually answers within a day. The page can’t be edited while it waits.")
    }

    /// Once approved, turning Visible on waits in Review & Push, as asked.
    @Test func anApprovedPageThatShouldBeVisibleQueuesVisible() async throws {
        let store = Sample.store()
        store.setVisibleWhenApproved(true, pageID: PageID.privateDiaryPushed, for: Sample.appID)
        let services = FakeProductPagesServices()
        let model = await pushedModel(.approved, services: services, store: store)
        let page = try ProductPagesTestModel.page(model, PageID.privateDiaryPushed)
        #expect(model.edits(of: page).isVisible == true)
        #expect(!model.makesVisibleWhenApproved(page))
        #expect(model.toast?.text == "Apple approved “Private diary”. Turning Visible on is in Review & Push, as you asked.")
        #expect(model.toast?.actionTitle == "Review & Push")
    }

    @Test func aRejectedPageForgetsToMakeItVisible() async throws {
        let store = Sample.store()
        store.setVisibleWhenApproved(true, pageID: PageID.privateDiaryPushed, for: Sample.appID)
        let model = await pushedModel(.rejected, services: FakeProductPagesServices(), store: store)
        let page = try ProductPagesTestModel.page(model, PageID.privateDiaryPushed)
        #expect(!model.makesVisibleWhenApproved(page))
        #expect(model.edits(of: page).isVisible == nil)
        #expect(model.primaryActionTitle(of: page) == "Submit for Review…")
    }

    @Test func theStatusBannersSayWhereEachPageStands() async throws {
        let model = await ProductPagesTestModel.make()
        let prompts = try ProductPagesTestModel.page(model, PageID.prompts)
        #expect(model.statusNote(of: prompts)?.title == "On the App Store, and visible.")
        #expect(model.statusNote(of: prompts)?.action == .edit)
        #expect(try model.statusNote(of: ProductPagesTestModel.page(model, PageID.therapists))?.title == "Approved, and hidden.")
        let year = try ProductPagesTestModel.page(model, PageID.year)
        #expect(model.statusNote(of: year)?.tone == .problem)
        #expect(model.statusNote(of: year)?.action == .openAppStoreConnect)
        #expect(try model.statusNote(of: ProductPagesTestModel.page(model, PageID.sleep))?.title == "In Review.")
        #expect(try model.statusNote(of: ProductPagesTestModel.page(model, PageID.privateDiary)) == nil)
        #expect(model.appStoreConnectURL.absoluteString == "https://appstoreconnect.apple.com/apps/\(Sample.appID)/distribution")

        // Edit… on an approved page prepares version 2 beside it.
        model.startNewVersion(of: prompts)
        #expect(model.isPreparingNewVersion(prompts))
        #expect(model.statusNote(of: prompts)?.title == "Version 1 stays on the App Store while you prepare version 2.")
    }

    @Test func aPageWithKeywordsThatShowsTheDefaultScreenshotsIsAWarning() async throws {
        let model = await pushedModel(.prepareForSubmission)
        // Private diary chooses keywords and has no screenshots of its own.
        let diary = try ProductPagesTestModel.page(model, PageID.privateDiaryPushed)
        let check = try #require(model.submitChecks(of: diary).first { $0.id == "screenshots" })
        #expect(check.isFine == false)
        #expect(check.detail.contains("Search results show a page’s first screenshots"))
        #expect(!check.detail.contains("The brief asks for"))

        let brief = ProductPageBrief(audience: "People who keep a diary", screens: "Lock first, then Write", source: "Claude Code")
        model.store.saveBrief(brief, pageName: "Private diary", for: Sample.appID)
        let briefed = try #require(model.submitChecks(of: diary).first { $0.id == "screenshots" })
        #expect(briefed.detail.hasSuffix("The brief asks for: Lock first, then Write"))

        // No keywords: nothing to show in search, so the default page's are fine.
        let year = try ProductPagesTestModel.page(model, PageID.year)
        #expect(model.submitChecks(of: year).first { $0.id == "screenshots" }?.isFine == true)
        // Its own screenshots somewhere: fine.
        let prompts = try ProductPagesTestModel.page(model, PageID.prompts)
        #expect(model.submitChecks(of: prompts).first { $0.id == "screenshots" }?.title == "Its own screenshots in 1 language")
    }

    /// A set Make Screenshots for This Page put in Review & Push goes with
    /// the page, so the page isn't warned about (board 52).
    @Test func screenshotsMadeForThePageAndQueuedCountAsItsOwn() async throws {
        let model = await pushedModel(.prepareForSubmission)
        let diary = try ProductPagesTestModel.page(model, PageID.privateDiaryPushed)
        let file = ProductPageScreenshotsPush.File(path: "/tmp/1.png", fileName: "1.png", fileSize: 10, checksum: "x")
        model.queue.upsert(model.builder.screenshotsChange([file], locale: "de-DE", displayType: .iPad, of: diary, hadOwn: false))
        let check = try #require(model.submitChecks(of: diary).first { $0.id == "screenshots" })
        #expect(check.isFine)
        #expect(check.title == "Its own screenshots in 1 language")
        #expect(check.detail.hasSuffix("iPad"))
    }

    @Test func theChecksSayWhatGoesToApple() async throws {
        let model = await pushedModel(.prepareForSubmission)
        let page = try ProductPagesTestModel.page(model, PageID.privateDiaryPushed)
        let checks = model.submitChecks(of: page)
        #expect(checks.map(\.id) == ["version", "screenshots", "rules", "deepLink"])
        #expect(checks.first?.title == "Version 1 of the page")
        #expect(checks.first { $0.id == "rules" }?.isFine == true)

        model.open(page.id)
        model.localeCode = "en-US"
        model.editText("Try it free for a week.")
        let refused = try model.submitChecks(of: ProductPagesTestModel.page(model, page.id))
        #expect(refused.first { $0.id == "rules" }?.isFine == false)
    }
}
