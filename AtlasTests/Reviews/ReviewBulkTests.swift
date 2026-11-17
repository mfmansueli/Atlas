//
//  ReviewBulkTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Reply to All: one message per language, sent under each review of a
/// group that has no reply yet.
@MainActor
@Suite("Reviews · Reply to All")
struct ReviewBulkTests {
    typealias Data = ReviewsTestData

    private func makeModel(_ services: FakeReviewsServices) -> ReviewsViewModel {
        let store = Data.store()
        store.add([Data.sync], for: Data.app.id)
        return ReviewsViewModel(app: Data.app, store: store, services: services)
    }

    @Test func thePlanHasOneRowPerLanguageThatHasAMessage() {
        let plan = ReviewBulkPlan.make(Data.sync, reviews: Data.reviews)
        #expect(plan.rows.map(\.languageCode) == ["de", "en"])
        #expect(plan.rows.map(\.reviewIDs) == [["de1", "de2"], ["us1"]])
        #expect(plan.rows[0].text == "Danke. 1.4 repariert das.")
        // The Japanese review has no message in its language.
        #expect(plan.leftOutCount == 1)
        #expect(plan.replyCount == 3)
        #expect(plan.title == "Reply to 3 reviews about iCloud sync since 1.3")
        #expect(plan.replyCount(selected: ["en"]) == 1)
    }

    @Test func aRegionalLanguageCodeMatchesItsBaseLanguage() {
        var theme = Data.sync
        theme.replies = [ReviewThemeReply(languageCode: "de-DE", text: "Danke.")]
        let plan = ReviewBulkPlan.make(theme, reviews: Data.reviews)
        #expect(plan.rows.map(\.languageCode) == ["de"])
        #expect(plan.rows.first?.reviewIDs == ["de1", "de2"])
    }

    @Test func aReviewThatAlreadyHasAReplyIsLeftOut() {
        var reviews = Data.reviews
        reviews[0].reply = Data.reply()
        let plan = ReviewBulkPlan.make(Data.sync, reviews: reviews)
        #expect(plan.rows.first { $0.languageCode == "de" }?.reviewIDs == ["de2"])
        let summary = ReviewThemeSummary.make(Data.sync, reviews: reviews)
        #expect(summary.count == 4)
        #expect(summary.replyCount == 2)
        #expect(summary.buttonTitle == "Reply to All 2…")
    }

    @Test func sendingRepliesToEachReviewInItsLanguage() async {
        let services = FakeReviewsServices()
        let model = makeModel(services)
        model.openBulk(Data.sync)
        #expect(model.bulkReplyCount == 3)
        #expect(model.bulkSendTitle == "Send 3 Replies")
        await model.sendBulk()
        #expect(services.sent.map(\.reviewID) == ["de1", "de2", "us1"])
        #expect(services.sent.map(\.text) == ["Danke. 1.4 repariert das.", "Danke. 1.4 repariert das.", "Thanks. 1.4 fixes it."])
        #expect(model.bulkPlan == nil)
        #expect(model.toast?.text == "3 replies sent in 2 languages. Apple shows them under the reviews, usually within a day.")
        #expect(model.count(for: .needsReply) == 1)
    }

    @Test func aLanguageTakenOutIsntSent() async throws {
        let services = FakeReviewsServices()
        let model = makeModel(services)
        model.openBulk(Data.sync)
        let german = try #require(model.bulkPlan?.rows.first)
        model.toggleBulk(german)
        #expect(model.bulkSendTitle == "Send 1 Reply")
        await model.sendBulk()
        #expect(services.sent.map(\.reviewID) == ["us1"])
    }

    @Test func whatAppleRefusesStaysInTheSheet() async {
        let services = FakeReviewsServices()
        services.refused = ["de2"]
        let model = makeModel(services)
        model.openBulk(Data.sync)
        await model.sendBulk()
        #expect(services.sent.map(\.reviewID) == ["de1", "us1"])
        #expect(model.bulkPlan?.rows.map(\.reviewIDs) == [["de2"]])
        #expect(model.errorMessage?.hasPrefix("2 replies sent; the rest couldn’t be:") == true)
    }

    @Test func aGroupSaysWhereItsReviewsComeFrom() {
        let summary = ReviewThemeSummary.make(Data.sync, reviews: Data.reviews)
        #expect(summary.whereText == "Austria 1 · Germany 1 · Japan 1 · 1 more")
        #expect(summary.isMostlyLow)
        #expect(summary.countText == "4 reviews")
        var price = Data.sync
        price.action = .openPricing(territory: "JP")
        #expect(ReviewThemeSummary.make(price, reviews: Data.reviews).buttonTitle == "Open Pricing for Japan")
        price.action = .suggestStorePage
        #expect(ReviewThemeSummary.make(price, reviews: Data.reviews).countText == "4 mentions")
    }
}
