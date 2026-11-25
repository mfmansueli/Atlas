//
//  AgeRatingCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Age rating against what the app says (2.3.6)")
struct AgeRatingCheckTests {
    private typealias Support = ContentRiskTestSupport
    private let check = AgeRatingCheck()

    private func risks(_ facts: ReviewRiskFacts) -> [ReviewRisk] {
        Support.risks(check.run(facts))
    }

    private func risk(_ id: String, in facts: ReviewRiskFacts) -> ReviewRisk? {
        risks(facts).first { $0.id == id }
    }

    // MARK: - Unanswered

    @Test func brumaLikeDatingAppWithTheDatingQuestionUnanswered() throws {
        let facts = Support.facts(
            name: "Bruma: Dating Nearby",
            texts: [Support.text(.description, "Meet new people near you and chat with your matches.")],
            unanswered: [.datingAndRelationships]
        )
        let found = risks(facts)
        let unanswered = try #require(found.first { $0.id == "ageRating:unanswered" })
        #expect(unanswered.level == .blocksReview)
        #expect(unanswered.howSure == .fairlySure)
        #expect(unanswered.fix.tool == "propose_age_rating")
        #expect(unanswered.fix.arguments["question"] == "datingAndRelationships")
        #expect(unanswered.fix.advice.contains(AgeRatingQuestion.datingAndRelationships.title))
        #expect(unanswered.evidence.contains { $0.excerpt.localizedCaseInsensitiveContains("dating") })
        // The unanswered question isn't flagged twice.
        #expect(!found.contains { $0.id == "ageRating:datingAndRelationships" })
    }

    @Test func manyUnansweredQuestionsAreSure() throws {
        let facts = Support.facts(unanswered: [.messaging, .advertising, .datingAndRelationships])
        let unanswered = try #require(risk("ageRating:unanswered", in: facts))
        #expect(unanswered.howSure == .sure)
        #expect(unanswered.title.contains("3"))
        #expect(unanswered.fix.arguments["question"] == "messaging,advertising,datingAndRelationships")
    }

    @Test func answeredQuestionnaireHasNoUnansweredRisk() {
        #expect(risk("ageRating:unanswered", in: Support.facts()) == nil)
    }

    // MARK: - Dating

    @Test func datingWordsWithDatingAnsweredNo() throws {
        let facts = Support.facts(texts: [Support.text(.subtitle, "Meet new people tonight")])
        let dating = try #require(risk("ageRating:datingAndRelationships", in: facts))
        #expect(dating.level == .likely)
        #expect(dating.fix.arguments["question"] == "datingAndRelationships")
        #expect(dating.evidence.contains { $0.place.contains(AgeRatingQuestion.datingAndRelationships.title) })
    }

    @Test func datingAnsweredYesIsFine() {
        let facts = Support.facts(
            texts: [Support.text(.subtitle, "Meet new people tonight")],
            ageRating: Support.answers([.datingAndRelationships: .affirmative])
        )
        #expect(risk("ageRating:datingAndRelationships", in: facts) == nil)
    }

    @Test func carbonDatingIsNotDating() {
        let facts = Support.facts(texts: [Support.text(.description, "Learn how carbon dating works, with fossils dating back millions of years.")])
        #expect(risks(facts).isEmpty)
    }

    // MARK: - Messaging and user content

    @Test func groupChatWithMessagingAnsweredNo() throws {
        let facts = Support.facts(texts: [Support.text(.description, "Plan trips together in a group chat.")])
        let messaging = try #require(risk("ageRating:messaging", in: facts))
        #expect(messaging.level == .likely)
        #expect(messaging.why.contains("group chat"))
    }

    @Test func anAIChatIsNotMessaging() {
        let facts = Support.facts(texts: [Support.text(.description, "Chat with an assistant that plans your trips.")])
        #expect(risk("ageRating:messaging", in: facts) == nil)
    }

    @Test func chatSDKInTheProjectShowsMessaging() throws {
        let facts = Support.facts(packages: ["stream-chat-swift"])
        let messaging = try #require(risk("ageRating:messaging", in: facts))
        #expect(messaging.evidence.first?.place.contains("Lumen") == true)
    }

    @Test func communityWithUserContentAnsweredNo() {
        let facts = Support.facts(texts: [Support.text(.description, "Post your recipes and join a community of cooks.")])
        #expect(risk("ageRating:userGeneratedContent", in: facts)?.level == .likely)
    }

    @Test func aDiscordCommunityIsOutsideTheApp() {
        let facts = Support.facts(texts: [Support.text(.description, "Questions? Join our Discord community.")])
        #expect(risk("ageRating:userGeneratedContent", in: facts) == nil)
    }

    // MARK: - Gambling, ads, web, health

    @Test func casinoGamesWithSimulatedGamblingNone() {
        let facts = Support.facts(texts: [Support.text(.description, "Spin classic casino slot machines.")])
        #expect(risk("ageRating:simulatedGambling", in: facts)?.level == .likely)
    }

    @Test func planningPokerIsNotGambling() {
        let facts = Support.facts(texts: [Support.text(.description, "Planning poker for agile teams.")])
        #expect(risk("ageRating:simulatedGambling", in: facts) == nil)
    }

    @Test func realMoneyGamblingCoversSimulated() {
        let facts = Support.facts(
            texts: [Support.text(.description, "Play poker for real prizes.")],
            ageRating: Support.answers([.gambling: .affirmative])
        )
        #expect(risk("ageRating:simulatedGambling", in: facts) == nil)
    }

    @Test func adsSDKWithAdvertisingAnsweredNo() throws {
        let facts = Support.facts(packages: ["swift-package-manager-google-mobile-ads"])
        let ads = try #require(risk("ageRating:advertising", in: facts))
        #expect(ads.level == .likely)
        #expect(ads.why.contains("swift-package-manager-google-mobile-ads"))
    }

    @Test func adsAnsweredYesIsFine() {
        let facts = Support.facts(ageRating: Support.answers([.advertising: .affirmative]), packages: ["swift-package-manager-google-mobile-ads"])
        #expect(risk("ageRating:advertising", in: facts) == nil)
    }

    @Test func aBrowserIsWorthALook() {
        let facts = Support.facts(texts: [Support.text(.subtitle, "Private browser with tabs")])
        #expect(risk("ageRating:webAccess", in: facts)?.level == .check)
    }

    @Test func aBrowserExtensionIsNotWebAccess() {
        let facts = Support.facts(texts: [Support.text(.description, "A Safari extension that hides cookie banners in your browser.")])
        #expect(risk("ageRating:webAccess", in: facts) == nil)
    }

    @Test func medicalWordsWithMedicalNone() {
        let facts = Support.facts(texts: [Support.text(.description, "Log symptoms and medication reminders.")])
        let medical = risk("ageRating:medical", in: facts)
        #expect(medical?.level == .check)
        #expect(medical?.howSure == .notVerySure)
    }

    @Test func medicalAnsweredInfrequentIsFine() {
        let facts = Support.facts(
            texts: [Support.text(.description, "Log symptoms and medication reminders.")],
            ageRating: Support.answers([.medical: .infrequent])
        )
        #expect(risk("ageRating:medical", in: facts) == nil)
    }

    @Test func healthCategoryPointsToWellness() {
        let facts = Support.facts(primaryCategory: "HEALTH_AND_FITNESS")
        #expect(risk("ageRating:wellness", in: facts) != nil)
    }

    // MARK: - Calm apps and gaps

    @Test func aPlainAppHasNothing() {
        let facts = Support.facts(name: "Tally", texts: [Support.text(.description, "Count anything with a tap. Widgets and iCloud sync.")])
        #expect(risks(facts).isEmpty)
    }

    @Test func withoutTheAnswersItIsNotChecked() {
        #expect(Support.isNotChecked(check.run(Support.facts(ageRating: nil))))
        var facts = Support.facts()
        facts.content = nil
        #expect(Support.isNotChecked(check.run(facts)))
    }

    @Test func idsAreStable() {
        let facts = Support.facts(texts: [Support.text(.subtitle, "Meet new people tonight")])
        #expect(risks(facts).map(\.id) == risks(facts).map(\.id))
    }
}
