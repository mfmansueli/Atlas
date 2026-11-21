//
//  ProductPageReviewWatchTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Following a custom product page with App Review: what's told between
/// two reads, and what's followed after.
@MainActor
@Suite("Custom Product Pages · following App Review")
struct ProductPageReviewWatchTests {
    typealias Sample = DebugProductPagesData
    typealias PageID = DebugProductPagesData.PageID

    private func page(_ state: ProductPageState, id: String = "p1", versionID: String = "v1", isDraft: Bool = false) -> ProductPage {
        ProductPage(
            id: id, name: "Sleep", url: nil, isVisible: false,
            versions: [ProductPageVersion(id: versionID, number: 1, state: state)], isDraft: isDraft
        )
    }

    @Test func theFirstReadFollowsWhatAppReviewHasAndTellsNothing() {
        let result = ProductPageReviewWatch.follow([page(.waitingForReview), page(.approved, id: "p2", versionID: "v2")], after: [:])
        #expect(result.moves.isEmpty)
        #expect(result.followed == ["v1": .waitingForReview])
    }

    @Test func eachStepWithAppReviewIsToldOnce() {
        var followed: [String: ProductPageState] = ["v1": .waitingForReview]
        var result = ProductPageReviewWatch.follow([page(.inReview)], after: followed)
        #expect(result.moves.map(\.state) == [.inReview])
        followed = result.followed
        #expect(followed == ["v1": .inReview])

        result = ProductPageReviewWatch.follow([page(.inReview)], after: followed)
        #expect(result.moves.isEmpty)

        result = ProductPageReviewWatch.follow([page(.approved)], after: followed)
        #expect(result.moves == [ProductPageReviewMove(pageID: "p1", pageName: "Sleep", state: .approved)])
        #expect(result.followed.isEmpty)
    }

    @Test func aPageTakenBackOrGoneIsDroppedQuietly() {
        let back = ProductPageReviewWatch.follow([page(.prepareForSubmission)], after: ["v1": .waitingForReview])
        #expect(back.moves.isEmpty)
        #expect(back.followed.isEmpty)
        let gone = ProductPageReviewWatch.follow([], after: ["v1": .inReview])
        #expect(gone.moves.isEmpty)
        #expect(gone.followed.isEmpty)
    }

    @Test func draftsAreNeverFollowed() {
        let result = ProductPageReviewWatch.follow([page(.waitingForReview, isDraft: true)], after: [:])
        #expect(result.followed.isEmpty)
    }

    @Test func whatsSaidNeverInventsTheReviewersMessage() {
        let rejected = ProductPageReviewMove(pageID: "p1", pageName: "Sleep", state: .rejected)
        #expect(rejected.announcement(appName: "Lumen") == "App Review sent back “Sleep”, a custom product page of Lumen. Its message is in App Store Connect.")
        let approved = ProductPageReviewMove(pageID: "p1", pageName: "Sleep", state: .accepted)
        #expect(approved.announcement(appName: "Lumen") == "Apple approved “Sleep”, a custom product page of Lumen.")
        #expect(ProductPageReviewMove(pageID: "p1", pageName: "Sleep", state: .waitingForReview).announcement(appName: "Lumen") == nil)
    }

    @Test func aNotificationGoesOnlyWhileSettingsAllowsIt() throws {
        let defaults = try #require(UserDefaults(suiteName: "pages.follow.\(UUID().uuidString)"))
        let preferences = NotificationPreferences(defaults: defaults)
        let notifier = AtlasNotifier(center: nil, preferences: preferences)
        let move = ProductPageReviewMove(pageID: "p1", pageName: "Sleep", state: .inReview)
        preferences.reviewStatus = true
        let told = AtlasNotifications.productPagesMoved([move], appName: "Lumen", appID: "a1", notifier: notifier)
        #expect(told.count == 1)
        #expect(notifier.sent.map(\.kind) == [.reviewStatus])
        #expect(notifier.sent.first?.title == "Lumen")

        preferences.reviewStatus = false
        AtlasNotifications.productPagesMoved([move], appName: "Lumen", appID: "a1", notifier: notifier)
        #expect(notifier.sent.count == 1)
    }

    // MARK: - In the section

    @Test func aPageSubmittedHereIsFollowedAndItsApprovalIsToldAtTheNextRead() async throws {
        let services = FakeProductPagesServices()
        services.pushPrivateDiary(.prepareForSubmission)
        let store = Sample.store()
        let model = await ProductPagesTestModel.make(services, store: store, queue: ChangeQueue())
        let page = try ProductPagesTestModel.page(model, PageID.privateDiaryPushed)
        await model.submit(page, makeVisible: false)
        #expect(store.followsReview(for: model.app.id))

        // Apple approved it before Atlas read it again.
        let index = try #require(services.snapshot.pages.firstIndex { $0.id == PageID.privateDiaryPushed })
        services.snapshot.pages[index].versions[0].state = .approved
        await model.load(force: true)
        #expect(model.toast?.text == "Apple approved “Private diary”, a custom product page of \(model.app.name).")
        #expect(!(store.archive(for: model.app.id).reviewStates ?? [:]).keys.contains("private-v1"))
    }

    @Test func cancellingTheSubmissionStopsFollowingIt() async throws {
        let services = FakeProductPagesServices()
        services.pushPrivateDiary(.prepareForSubmission)
        let store = Sample.store()
        let model = await ProductPagesTestModel.make(services, store: store, queue: ChangeQueue())
        let page = try ProductPagesTestModel.page(model, PageID.privateDiaryPushed)
        await model.submit(page, makeVisible: false)
        let waiting = try ProductPagesTestModel.page(model, PageID.privateDiaryPushed)
        await model.cancelSubmission(of: waiting)
        #expect(store.archive(for: model.app.id).reviewStates?["private-v1"] == nil)
    }
}
