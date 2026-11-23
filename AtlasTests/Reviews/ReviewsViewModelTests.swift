//
//  ReviewsViewModelTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The Reviews section: what the list shows, replying one review at a
/// time, Undo, and what Free leaves out.
@MainActor
@Suite("ReviewsViewModel")
struct ReviewsViewModelTests {
    typealias Data = ReviewsTestData

    private func makeModel(store: ReviewsStore = Data.store(), services: FakeReviewsServices = FakeReviewsServices()) -> ReviewsViewModel {
        let model = ReviewsViewModel(app: Data.app, store: store, services: services)
        model.now = { Data.now }
        return model
    }

    @Test func needsAReplyListsUnansweredReviewsUnderFiveStarsNewestFirst() {
        let model = makeModel()
        #expect(model.shownReviews.map(\.id) == ["de1", "de2", "jp1", "us1"])
        #expect(model.count(for: .needsReply) == 4)
        #expect(model.count(for: .all) == nil)
        model.filter = .lowStars
        #expect(model.shownReviews.map(\.id) == ["de1", "de2", "jp1", "us1"])
        model.filter = .replied
        #expect(model.shownReviews.map(\.id) == ["fr1"])
        model.filter = .all
        #expect(model.shownReviews.count == 6)
    }

    @Test func countryAndSortNarrowAndOrderTheList() {
        let model = makeModel()
        model.filter = .all
        model.territoryFilter = "US"
        #expect(model.shownReviews.map(\.id) == ["us1", "us2"])
        model.sort = .highestRating
        #expect(model.shownReviews.map(\.id) == ["us2", "us1"])
        #expect(model.territories.first?.code == "US")
        #expect(model.territories.first?.count == 2)
    }

    @Test func aStaleStoreIsReadAgainAndAFreshOneIsnt() async {
        let services = FakeReviewsServices()
        let store = ReviewsStore()
        store.now = { Data.now }
        let model = makeModel(store: store, services: services)
        await model.load()
        #expect(services.readCursors.count == 1)
        #expect(model.hasLoaded)
        #expect(model.reviews.count == 6)
        await model.load()
        #expect(services.readCursors.count == 1)
        await model.load(force: true)
        #expect(services.readCursors.count == 2)
        // Ratings are asked for the storefronts with reviews, and the U.S.
        #expect(services.ratingCountries == ["DE", "AT", "JP", "US", "FR"])
    }

    @Test func aFailedReadKeepsWhatWasThereAndSaysWhy() async {
        let services = FakeReviewsServices()
        services.readError = .server(statusCode: 500, detail: "Try later.")
        let model = makeModel(services: services)
        await model.load(force: true)
        #expect(model.errorMessage != nil)
        #expect(model.reviews.count == 6)
    }

    @Test func showMoreReadsTheNextPage() async {
        let services = FakeReviewsServices(next: "cursor-2")
        services.pages["cursor-2"] = ReviewsPage(reviews: [Data.review("old1", daysAgo: 70)], next: nil)
        let model = makeModel(store: Data.store(next: "cursor-2"), services: services)
        #expect(model.canLoadMore)
        await model.loadMore()
        #expect(services.readCursors == ["cursor-2"])
        #expect(model.reviews.count == 7)
        #expect(!model.canLoadMore)
    }

    @Test func sendingASuggestionRepliesAndKeepsTheReviewInView() async {
        let services = FakeReviewsServices()
        let store = Data.store()
        store.add([Data.suggestion("de1")], for: Data.app.id)
        let model = makeModel(store: store, services: services)
        let review = model.shownReviews[0]
        #expect(model.suggestion(for: review)?.text == "Danke!")
        await model.sendSuggestion(for: review)
        #expect(services.sent.map(\.text) == ["Danke!"])
        #expect(services.sent.map(\.reviewID) == ["de1"])
        #expect(model.reviews.first { $0.id == "de1" }?.reply?.text == "Danke!")
        // It has a reply now, but stays where the person was looking.
        #expect(model.shownReviews.map(\.id).contains("de1"))
        #expect(model.sentNow == ["de1"])
        #expect(model.toast?.text == "Reply sent to Germany. It shows on the App Store, usually within a day.")
        #expect(model.count(for: .needsReply) == 3)
    }

    @Test func undoTakesANewReplyOffTheAppStore() async {
        let services = FakeReviewsServices()
        let model = makeModel(services: services)
        await model.send("Thanks", to: model.shownReviews[0])
        await model.undoReply()
        #expect(services.deleted == ["sent-1"])
        #expect(model.reviews.first { $0.id == "de1" }?.reply == nil)
        #expect(model.sentNow.isEmpty)
        #expect(model.toast == nil)
    }

    @Test func undoAfterEditingPutsTheEarlierReplyBack() async {
        let services = FakeReviewsServices()
        let model = makeModel(services: services)
        model.filter = .replied
        let review = model.shownReviews[0]
        model.startEditing(review)
        #expect(model.draft(for: review) == "Merci !")
        model.drafts[review.id] = "Merci beaucoup !"
        await model.sendDraft(for: review)
        #expect(model.editingID == nil)
        await model.undoReply()
        #expect(services.sent.map(\.text) == ["Merci beaucoup !", "Merci !"])
        #expect(services.deleted.isEmpty)
        #expect(model.reviews.first { $0.id == "fr1" }?.reply?.text == "Merci !")
    }

    @Test func aRefusedReplyStaysASuggestionAndSaysWhy() async {
        let services = FakeReviewsServices()
        services.refused = ["de1"]
        let store = Data.store()
        store.add([Data.suggestion("de1")], for: Data.app.id)
        let model = makeModel(store: store, services: services)
        let review = model.shownReviews[0]
        await model.sendSuggestion(for: review)
        #expect(model.replyErrors["de1"] != nil)
        #expect(model.suggestion(for: review) != nil)
        #expect(model.toast == nil)
    }

    @Test func anEmptyOrTooLongReplyIsntSent() async {
        let services = FakeReviewsServices()
        let model = makeModel(services: services)
        #expect(!model.canSend("   "))
        #expect(!model.canSend(String(repeating: "a", count: ReviewText.replyLimit + 1)))
        #expect(model.canSend(String(repeating: "a", count: ReviewText.replyLimit)))
        await model.send("  ", to: model.shownReviews[0])
        #expect(services.sent.isEmpty)
    }

    @Test func dismissKeepsTheReviewAndRestoreBringsTheSuggestionBack() {
        let store = Data.store()
        store.add([Data.suggestion("de1")], for: Data.app.id)
        let model = makeModel(store: store)
        let review = model.shownReviews[0]
        model.dismissSuggestion(for: review)
        #expect(model.suggestion(for: review) == nil)
        #expect(model.isDismissed(review))
        #expect(model.shownReviews.map(\.id).contains("de1"))
        model.restoreSuggestion(for: review)
        #expect(model.suggestion(for: review) != nil)
    }

    @Test func freeHasNoSuggestionsAndStartsFromAnEmptyReply() {
        let store = Data.store()
        store.add([Data.suggestion("de1")], for: Data.app.id)
        let model = makeModel(store: store)
        model.isPro = false
        let review = model.shownReviews[0]
        #expect(model.suggestion(for: review) == nil)
        #expect(model.suggestionCount == 0)
        #expect(!model.isDismissed(review))
        model.startEditing(review)
        #expect(model.drafts[review.id] == "")
        #expect(model.draftMeaning(for: review) == nil)
    }

    @Test func aGroupFiltersTheListWhateverTheFilter() {
        let store = Data.store()
        var praise = Data.sync
        praise.id = "praise"
        praise.reviewIDs = ["us2", "fr1"]
        praise.action = .showReviews
        store.add([Data.sync, praise], for: Data.app.id)
        let model = makeModel(store: store)
        model.show(praise)
        #expect(model.shownReviews.map(\.id) == ["us2", "fr1"])
        #expect(model.selectedTheme?.id == "praise")
        model.show(nil)
        #expect(model.shownReviews.count == 4)
        #expect(model.theme(of: Data.reviews[0])?.id == "sync")
    }

    @Test func theListGrowsTwentyAtATime() {
        let many = (0..<45).map { Data.review("r\($0)", daysAgo: Double($0)) }
        let model = makeModel(store: Data.store(reviews: many))
        #expect(model.listedReviews.count == 20)
        #expect(model.hiddenCount == 25)
        #expect(model.showMoreTitle == "25 more need a reply")
        model.showMore()
        #expect(model.listedReviews.count == 40)
        model.filter = .all
        #expect(model.listedReviews.count == 20)
    }
}
