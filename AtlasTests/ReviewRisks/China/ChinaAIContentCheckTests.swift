//
//  ChinaAIContentCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("China mainland: AI-generated content")
struct ChinaAIContentCheckTests {
    private typealias Support = ContentRiskTestSupport
    private let check = ChinaAIContentCheck()

    private let cueNotes = "Cue’s writing assistant runs on Anthropic’s Claude API. Sign in with the demo account."

    private func cue(_ answers: ComplianceAnswers = ComplianceAnswers(), soldInChina: Bool = true) -> ReviewRiskFacts {
        Support.facts(
            name: "Cue",
            texts: [Support.text(.description, "Speaker notes that keep you on time.")],
            reviewNotes: cueNotes,
            compliance: Support.compliance(soldInChina: soldInChina, answers: answers)
        )
    }

    private func risks(_ facts: ReviewRiskFacts) -> [ReviewRisk] {
        Support.risks(check.run(facts))
    }

    private static let filing = AIFilingDetails(number: "Beijing-Model-2026-0001", name: "Cue Writer")

    @Test func cueLikeSoldInChinaUnanswered() throws {
        let found = risks(cue())
        let risk = try #require(found.first)
        #expect(found.count == 1)
        #expect(risk.id == "chinaAIContent:unanswered")
        #expect(risk.level == .blocksReview)
        #expect(risk.fix.tool == "propose_compliance_answers")
        #expect(risk.fix.arguments == ["rule": "aiGeneratedContent"])
        #expect(risk.evidence.contains { $0.excerpt.contains("Anthropic") })
    }

    @Test func cueLikeAnsweredNoWhileTheNotesNameAModel() throws {
        let risk = try #require(risks(cue(ComplianceAnswers(aiContent: AIContentAnswer(offersAI: false)))).first)
        #expect(risk.id == "chinaAIContent:answeredNo")
        #expect(risk.level == .likely)
        #expect(risk.howSure == .fairlySure)
        #expect(risk.fix.advice.contains("geoblocked"))
    }

    @Test func cueLikeYesWithAUSModel() {
        var answers = Support.declared(ComplianceAnswers(aiContent: AIContentAnswer(offersAI: true, filing: Self.filing)))
        answers.needsSecurityAssessment = false
        let found = risks(cue(answers))
        #expect(found.map(\.id) == ["chinaAIContent:usProvider"])
        #expect(found.first?.level == .check)
    }

    @Test func yesWithoutTheFilingBlocks() throws {
        let answers = ComplianceAnswers(aiContent: AIContentAnswer(offersAI: true, filing: AIFilingDetails(number: "Beijing-Model-2026-0001")))
        let risk = try #require(risks(cue(answers)).first)
        #expect(risk.id == "chinaAIContent:filing")
        #expect(risk.level == .blocksReview)
    }

    @Test func anotherCompanysModelNeedsItsOwner() throws {
        let filing = AIFilingDetails(number: "Beijing-Model-2026-0001", name: "Cue Writer", usesAnotherCompanysModel: true)
        let risk = try #require(risks(cue(ComplianceAnswers(aiContent: AIContentAnswer(offersAI: true, filing: filing)))).first)
        #expect(risk.id == "chinaAIContent:filing")
    }

    @Test func yesNotEnteredYet() {
        let found = risks(Support.facts(
            texts: [Support.text(.description, "Turn sketches into art with AI.")],
            compliance: Support.compliance(soldInChina: true, answers: ComplianceAnswers(aiContent: AIContentAnswer(offersAI: true, filing: Self.filing)))
        ))
        #expect(found.map(\.id) == ["chinaAIContent:notEntered"])
    }

    @Test func noWithoutAIAndDeclaredIsQuiet() {
        let answers = Support.declared(ComplianceAnswers(aiContent: AIContentAnswer(offersAI: false)))
        let facts = Support.facts(
            texts: [Support.text(.description, "Daily horoscope for Gemini, Leo and every sign.")],
            compliance: Support.compliance(soldInChina: true, answers: answers)
        )
        #expect(risks(facts).isEmpty)
    }

    @Test func noWithoutAINotDeclaredIsWorthALook() {
        let facts = Support.facts(compliance: Support.compliance(soldInChina: true, answers: ComplianceAnswers(aiContent: AIContentAnswer(offersAI: false))))
        let found = risks(facts)
        #expect(found.map(\.id) == ["chinaAIContent:notEntered"])
        #expect(found.first?.level == .check)
    }

    @Test func notSoldInChinaStaysQuietOnceDeclared() {
        #expect(risks(cue(Support.declared(), soldInChina: false)).isEmpty)
    }

    @Test func notSoldInChinaAndNotDeclaredSaysAnswerNo() {
        let found = risks(cue(soldInChina: false))
        #expect(found.map(\.id) == ["chinaAIContent:notSoldAnswerNo"])
        #expect(found.first?.level == .check)
    }

    @Test func stoppingSalesInChinaCountsAsNotSold() {
        let facts = Support.facts(
            name: "Cue",
            reviewNotes: cueNotes,
            compliance: Support.compliance(soldInChina: true, answers: Support.declared(), stopsSellingInChina: true)
        )
        #expect(risks(facts).isEmpty)
    }

    @Test func chineseWordsCount() {
        let facts = Support.facts(
            texts: [Support.text(.description, "一键AI绘画，生成你的头像", locale: "zh-Hans")],
            compliance: Support.compliance(soldInChina: true, answers: ComplianceAnswers(aiContent: AIContentAnswer(offersAI: false)))
        )
        #expect(risks(facts).first?.id == "chinaAIContent:answeredNo")
    }

    @Test func projectPackagesCount() {
        let facts = Support.facts(
            compliance: Support.compliance(soldInChina: true, answers: Support.declared(ComplianceAnswers(aiContent: AIContentAnswer(offersAI: false)))),
            packages: ["openai"]
        )
        #expect(risks(facts).first?.id == "chinaAIContent:answeredNo")
    }

    @Test func withoutAppComplianceItIsNotChecked() {
        #expect(Support.isNotChecked(check.run(Support.facts(compliance: nil))))
    }
}
