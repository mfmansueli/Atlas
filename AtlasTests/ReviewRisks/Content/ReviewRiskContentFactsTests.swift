//
//  ReviewRiskContentFactsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@MainActor
@Suite("Content facts for App Review risks")
struct ReviewRiskContentFactsTests {
    private typealias Support = ContentRiskTestSupport

    private let ids = AppInformationResourceIDs(appID: "app1", appInfoID: "info1", ageRatingDeclarationID: "declaration1")

    /// Every question answered, except `blank`.
    private func values(blank: Set<AgeRatingQuestion>) -> AgeRatingValues {
        var apiValues: [String: AppInformationAPIValue] = [:]
        for question in AgeRatingQuestion.allCases {
            apiValues[question.apiKey] = blank.contains(question) ? .null : question.defaultAnswer.apiValue
        }
        return AgeRatingValues(answers: AgeRatingAnswers(attributes: apiValues), apiValues: apiValues)
    }

    @Test func unansweredQuestionsLeaveOutQueuedAnswers() throws {
        let builder = AppInformationChangeBuilder(appID: "app1", ids: ids, versionString: "1.0")
        let values = values(blank: [.datingAndRelationships, .sharedLocation])
        let queued = try #require(builder.ageAnswerChange(.sharedLocation, from: values, to: .negative))
        let unanswered = ReviewRiskFactsLoader.unansweredQuestions(values, builder: builder, changes: [queued])
        #expect(unanswered == [.datingAndRelationships])
    }

    @Test func everyAnswerMeansNothingUnanswered() {
        let builder = AppInformationChangeBuilder(appID: "app1", ids: ids, versionString: "1.0")
        #expect(ReviewRiskFactsLoader.unansweredQuestions(values(blank: []), builder: builder, changes: []).isEmpty)
    }

    @Test func reviewNotesBecomeAText() {
        let texts = ReviewRiskFactsLoader.contentTexts(nil, reviewNotes: "Uses OpenAI for summaries.")
        #expect(texts.count == 1)
        #expect(texts.first?.place == .reviewNotes)
        #expect(ReviewRiskFactsLoader.contentTexts(nil, reviewNotes: "  ").isEmpty)
    }

    @Test func soldInChinaFollowsStoppingSales() {
        #expect(ReviewRiskContentFacts(compliance: Support.compliance(soldInChina: true)).isSoldInChina)
        #expect(!ReviewRiskContentFacts(compliance: Support.compliance(soldInChina: true, stopsSellingInChina: true)).isSoldInChina)
        #expect(!ReviewRiskContentFacts(compliance: Support.compliance(soldInChina: false)).isSoldInChina)
        #expect(!ReviewRiskContentFacts().isSoldInChina)
    }

    @Test func sharedTextsComeFirstWithOwnReviewNotes() {
        var facts = Support.facts(texts: [Support.text(.description, "Own copy")], reviewNotes: "Notes here")
        facts.texts = ReviewRiskTextFacts(texts: [Support.text(.description, "Shared copy", locale: "de-DE")])
        let texts = ReviewRiskSignalScanner.texts(in: facts)
        #expect(texts.map(\.text) == ["Shared copy", "Notes here"])
    }

    @Test func signalsReadThePersonsPlace() throws {
        let facts = Support.facts(texts: [Support.text(.description, "Chat with friends in rooms.", locale: "en-US")])
        let signal = try #require(ReviewRiskSocialSignals(facts).of(.messaging).first)
        #expect(signal.evidence.place == "Description · en-US")
        #expect(signal.evidence.locale == "en-US")
        #expect(signal.term == "Chat with friends")
    }

    @Test func aiSignalsSplitUSProviders() {
        let facts = Support.facts(reviewNotes: "Summaries come from Gemini; images from Stable Diffusion.")
        let signals = ReviewRiskAISignals(facts)
        #expect(signals.usProviders.map(\.term) == ["Gemini"])
        #expect(signals.signals.contains { $0.topic == .otherAIProvider })
    }

    @Test func geminiInStoreTextsIsAZodiacSign() {
        let facts = Support.facts(texts: [Support.text(.description, "Your Gemini horoscope, every morning.")])
        #expect(ReviewRiskAISignals(facts).isEmpty)
    }

    /// A calm app not sold in China mainland, with both declarations
    /// entered: none of the content checks says anything.
    @Test func aCalmAppNotSoldInChinaStaysQuiet() {
        let facts = Support.facts(
            name: "Tally",
            texts: [Support.text(.description, "Count anything with a tap. Summaries with AI each week.")],
            reviewNotes: "No account needed."
        )
        let checks: [any ReviewRiskCheck] = [AgeRatingCheck(), UserContentCheck(), ChinaAIContentCheck(), ChinaSecurityAssessmentCheck()]
        for check in checks {
            #expect(Support.risks(check.run(facts)).isEmpty, "\(check.id)")
        }
    }
}
