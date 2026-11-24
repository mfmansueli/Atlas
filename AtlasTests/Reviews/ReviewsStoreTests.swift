//
//  ReviewsStoreTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What Atlas keeps of an app's reviews: the reviews read, the
/// suggested replies, the groups, and what the person dismissed.
@MainActor
@Suite("ReviewsStore")
struct ReviewsStoreTests {
    typealias Data = ReviewsTestData

    @Test func aFirstPageReplacesWhatWasReadAndStampsIt() {
        let store = ReviewsStore()
        store.now = { Data.now }
        #expect(store.isStale(Data.app.id))
        store.setFirstPage(ReviewsPage(reviews: Data.reviews, next: "cursor-2"), currentVersion: "1.3", for: Data.app.id)
        let archive = store.archive(for: Data.app.id)
        #expect(archive.reviews.count == 6)
        #expect(archive.next == "cursor-2")
        #expect(archive.currentVersion == "1.3")
        #expect(archive.fetchedAt == Data.now)
        #expect(!store.isStale(Data.app.id))
        store.now = { Data.now.addingTimeInterval(ReviewsStore.maximumAge + 1) }
        #expect(store.isStale(Data.app.id))
    }

    @Test func morePagesAreAddedWithoutRepeatingAReview() {
        let store = Data.store(next: "cursor-2")
        store.append(ReviewsPage(reviews: [Data.review("old1", daysAgo: 60), Data.reviews[0]], next: nil), for: Data.app.id)
        let archive = store.archive(for: Data.app.id)
        #expect(archive.reviews.count == 7)
        #expect(archive.next == nil)
    }

    @Test func applesCountOfWrittenReviewsIsKeptAcrossPages() {
        let store = ReviewsStore()
        store.now = { Data.now }
        #expect(store.archive(for: Data.app.id).writtenCount == nil)
        store.setFirstPage(ReviewsPage(reviews: Data.reviews, next: "cursor-2", total: 1206), currentVersion: "1.3", for: Data.app.id)
        #expect(store.archive(for: Data.app.id).writtenCount == 1206)
        // A page without Apple's count keeps the one read before.
        store.append(ReviewsPage(reviews: [Data.review("old1", daysAgo: 60)], next: "cursor-3"), for: Data.app.id)
        #expect(store.archive(for: Data.app.id).writtenTotal == 1206)
        store.append(ReviewsPage(reviews: [], next: nil, total: 1210), for: Data.app.id)
        #expect(store.archive(for: Data.app.id).writtenCount == 1210)
    }

    @Test func withoutApplesCountEveryReviewReadIsTheCount() {
        #expect(Data.store().archive(for: Data.app.id).writtenCount == 6)
        // Older pages Atlas hasn't read: unknown.
        #expect(Data.store(next: "cursor-2").archive(for: Data.app.id).writtenCount == nil)
        // Apple's count never says fewer than the reviews read.
        var archive = ReviewsArchive(reviews: Data.reviews, writtenTotal: 2, fetchedAt: Data.now)
        #expect(archive.writtenCount == 6)
        archive.writtenTotal = nil
        archive.next = "cursor-2"
        #expect(archive.writtenCount == nil)
    }

    @Test func aSuggestionIsKeptOnlyForAReviewThatWasRead() {
        let store = Data.store()
        let kept = store.add([Data.suggestion("de1"), Data.suggestion("nobody")], for: Data.app.id)
        #expect(kept.map(\.reviewID) == ["de1"])
        #expect(store.suggestionCount(for: Data.app.id) == 1)
    }

    @Test func aRepliedReviewHasNoOpenSuggestion() {
        let store = Data.store()
        store.add([Data.suggestion("de1"), Data.suggestion("fr1")], for: Data.app.id)
        // fr1 already has a reply.
        #expect(store.suggestionCount(for: Data.app.id) == 1)
        store.setReply(Data.reply(), reviewID: "de1", for: Data.app.id)
        #expect(store.suggestionCount(for: Data.app.id) == 0)
        #expect(store.archive(for: Data.app.id).needsReplyCount == 3)
    }

    @Test func dismissingHidesASuggestionUntilItIsRestoredOrSentAgain() {
        let store = Data.store()
        store.add([Data.suggestion("de1")], for: Data.app.id)
        store.dismissSuggestion(reviewID: "de1", for: Data.app.id)
        #expect(store.suggestionCount(for: Data.app.id) == 0)
        store.restoreSuggestion(reviewID: "de1", for: Data.app.id)
        #expect(store.suggestionCount(for: Data.app.id) == 1)
        store.dismissSuggestion(reviewID: "de1", for: Data.app.id)
        // A new suggestion from the assistant is a new offer.
        store.add([Data.suggestion("de1", text: "Neu")], for: Data.app.id)
        #expect(store.archive(for: Data.app.id).openSuggestion(for: Data.reviews[0])?.text == "Neu")
    }

    @Test func whatBelongedToReviewsNoLongerReadIsDropped() {
        let store = Data.store()
        store.add([Data.suggestion("de1"), Data.suggestion("jp1")], for: Data.app.id)
        store.keep(["jp1": ReviewTranslation(title: "t", body: "b")], for: Data.app.id)
        store.setFirstPage(ReviewsPage(reviews: [Data.reviews[0]], next: nil), currentVersion: nil, for: Data.app.id)
        let archive = store.archive(for: Data.app.id)
        #expect(archive.suggestions.keys.sorted() == ["de1"])
        #expect(archive.translations.isEmpty)
        // A read that doesn't say the version keeps the one known.
        #expect(archive.currentVersion == "1.3")
    }

    @Test func groupsAreMergedByIDOrSetWhole() {
        let store = Data.store()
        store.add([Data.sync], for: Data.app.id)
        var renamed = Data.sync
        renamed.title = "Sync"
        store.add([renamed], for: Data.app.id)
        #expect(store.archive(for: Data.app.id).themes.map(\.title) == ["Sync"])
        var price = Data.sync
        price.id = "price"
        store.setThemes([price], for: Data.app.id)
        #expect(store.archive(for: Data.app.id).themes.map(\.id) == ["price"])
    }

    @Test func everythingIsKeptOnDiskPerApp() {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ReviewsStoreTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ReviewsStore(directory: directory)
        store.now = { Data.now }
        store.setFirstPage(ReviewsPage(reviews: Data.reviews, next: nil), currentVersion: "1.3", for: Data.app.id)
        store.add([Data.suggestion("de1")], for: Data.app.id)
        store.add([Data.sync], for: Data.app.id)
        store.setTranslates(false)

        let reopened = ReviewsStore(directory: directory)
        let archive = reopened.archive(for: Data.app.id)
        #expect(archive.reviews.map(\.id) == Data.reviews.map(\.id))
        #expect(archive.suggestions["de1"]?.text == "Danke!")
        #expect(archive.themes == [Data.sync])
        #expect(archive.fetchedAt == Data.now)
        #expect(!reopened.settings.translates)
        #expect(reopened.archive(for: "another-app").reviews.isEmpty)
    }
}
