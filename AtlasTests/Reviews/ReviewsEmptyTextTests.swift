//
//  ReviewsEmptyTextTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// Board 74 · 6 and 8: what Reviews says when there's nothing to show,
/// and when Show All Reviews is offered.
@MainActor
@Suite("Reviews empty states")
struct ReviewsEmptyTextTests {
    typealias Data = ReviewsTestData

    @Test func eachFilterSaysWhatWouldShowUp() {
        let need = ReviewsEmptyText.make(filter: .needsReply, hasTheme: false, hasTerritory: false)
        #expect(need.title == "Every review has a reply")
        #expect(need.text == "New reviews that need one show up here.")
        #expect(need.showsAllReviews)
        #expect(ReviewsEmptyText.make(filter: .lowStars, hasTheme: false, hasTerritory: false).title == "No 1 or 2 star reviews")
        #expect(ReviewsEmptyText.make(filter: .replied, hasTheme: false, hasTerritory: false).title == "No replies yet")
    }

    @Test func showAllReviewsOnlyWhenSomethingHidesThem() {
        let all = ReviewsEmptyText.make(filter: .all, hasTheme: false, hasTerritory: false)
        #expect(all.title == "No reviews yet")
        #expect(!all.showsAllReviews, "All already shows everything")
        #expect(ReviewsEmptyText.make(filter: .all, hasTheme: false, hasTerritory: true).showsAllReviews)
        #expect(ReviewsEmptyText.make(filter: .all, hasTheme: true, hasTerritory: false).showsAllReviews)
    }

    @Test func aGroupOrACountryNamesWhatsChosen() {
        #expect(ReviewsEmptyText.make(filter: .needsReply, hasTheme: true, hasTerritory: true).title == "No reviews about this")
        #expect(ReviewsEmptyText.make(filter: .all, hasTheme: false, hasTerritory: true).title == "No reviews in this country")
        #expect(ReviewsEmptyText.make(filter: .lowStars, hasTheme: false, hasTerritory: true).title == "No 1 or 2 star reviews")
    }

    @Test func titlesStayShort() {
        for filter in ReviewFilter.allCases {
            for theme in [false, true] {
                for territory in [false, true] {
                    let text = ReviewsEmptyText.make(filter: filter, hasTheme: theme, hasTerritory: territory)
                    #expect(text.title.split(separator: " ").count <= 8, "\(text.title)")
                    #expect(text.text.count <= 110, "\(text.text)")
                }
            }
        }
    }

    @Test func theSectionIsEmptyOnlyWithoutAnyReview() {
        let withReviews = ReviewsViewModel(app: Data.app, store: Data.store(), services: FakeReviewsServices())
        #expect(!withReviews.showsEmptyState)
        let none = ReviewsViewModel(app: Data.app, store: Data.store(reviews: []), services: FakeReviewsServices())
        #expect(none.showsEmptyState)
        let unread = ReviewsViewModel(app: Data.app, store: ReviewsStore(), services: FakeReviewsServices())
        #expect(!unread.showsEmptyState, "Before the first read it's the skeleton")
    }

    @Test func showAllReviewsClearsEveryFilter() {
        let model = ReviewsViewModel(app: Data.app, store: Data.store(), services: FakeReviewsServices())
        model.filter = .lowStars
        model.territoryFilter = "US"
        #expect(model.emptyListText.showsAllReviews)
        model.showAllReviews()
        #expect(model.filter == .all)
        #expect(model.territoryFilter == nil)
        #expect(model.themeFilter == nil)
        #expect(model.shownReviews.count == Data.reviews.count)
    }
}
