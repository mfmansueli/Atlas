//
//  ChinaSecurityAssessmentCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("China mainland: Security Assessment")
struct ChinaSecurityAssessmentCheckTests {
    private typealias Support = ContentRiskTestSupport
    private let check = ChinaSecurityAssessmentCheck()

    private func facts(_ description: String, answers: ComplianceAnswers = ComplianceAnswers(), soldInChina: Bool = true) -> ReviewRiskFacts {
        Support.facts(
            texts: [Support.text(.description, description)],
            compliance: Support.compliance(soldInChina: soldInChina, answers: answers)
        )
    }

    private func risks(_ facts: ReviewRiskFacts) -> [ReviewRisk] {
        Support.risks(check.run(facts))
    }

    private let answeredNo = ComplianceAnswers(needsSecurityAssessment: false)

    @Test func soldInChinaUnansweredBlocks() throws {
        let risk = try #require(risks(facts("Track your habits.")).first)
        #expect(risk.id == "chinaSecurityAssessment:unanswered")
        #expect(risk.level == .blocksReview)
        #expect(risk.fix.arguments == ["rule": "securityAssessment"])
    }

    @Test func noWithAGroupChat() throws {
        let risk = try #require(risks(facts("Plan trips in a group chat with friends.", answers: answeredNo)).first)
        #expect(risk.id == "chinaSecurityAssessment:answeredNo")
        #expect(risk.level == .likely)
        #expect(risk.howSure == .fairlySure)
    }

    @Test func noWithEndToEndEncryptedMessages() {
        let found = risks(facts("Every note is end-to-end encrypted.", answers: answeredNo))
        #expect(found.first?.id == "chinaSecurityAssessment:answeredNo")
    }

    @Test func noWithAIContentPeopleShare() {
        let found = risks(facts("Make AI art and share your creations.", answers: answeredNo))
        #expect(found.first?.id == "chinaSecurityAssessment:answeredNo")
    }

    @Test func noWithMessagingAnsweredYes() {
        var facts = facts("Track your habits.", answers: answeredNo)
        facts.content?.ageRating = Support.answers([.messaging: .affirmative])
        #expect(risks(facts).first?.id == "chinaSecurityAssessment:answeredNo")
    }

    @Test func sharingAloneIsNotEnough() {
        let found = risks(facts("Share your photos with friends.", answers: Support.declared(answeredNo)))
        #expect(found.isEmpty)
    }

    @Test func noNotEnteredIsWorthALook() {
        let found = risks(facts("Track your habits.", answers: answeredNo))
        #expect(found.map(\.id) == ["chinaSecurityAssessment:notEntered"])
    }

    @Test func yesRemindsTheUploads() throws {
        let risk = try #require(risks(facts("Live streams from your city.", answers: ComplianceAnswers(needsSecurityAssessment: true))).first)
        #expect(risk.id == "chinaSecurityAssessment:uploads")
        #expect(risk.level == .check)
        #expect(risk.why.contains("2"))
    }

    @Test func yesDeclaredIsQuiet() {
        #expect(risks(facts("Live streams from your city.", answers: Support.declared(ComplianceAnswers(needsSecurityAssessment: true)))).isEmpty)
    }

    @Test func notSoldInChinaStaysQuietOnceDeclared() {
        #expect(risks(facts("Group chat with your team.", answers: Support.declared(), soldInChina: false)).isEmpty)
    }

    @Test func notSoldInChinaAndNotDeclaredSaysAnswerNo() {
        let found = risks(facts("Group chat with your team.", soldInChina: false))
        #expect(found.map(\.id) == ["chinaSecurityAssessment:notSoldAnswerNo"])
        #expect(found.first?.level == .check)
    }

    @Test func withoutAppComplianceItIsNotChecked() {
        #expect(Support.isNotChecked(check.run(Support.facts(compliance: nil))))
    }
}
