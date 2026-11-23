//
//  ChinaDeclarationTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// China mainland's Security Assessment and AI-generated content
/// declarations: asked of every app, sold there or not, answered Yes (the
/// AI one with its filing) or No here, then entered in App Store Connect and
/// marked as declared. An app not sold there, or stopping sales there,
/// answers No.
@Suite("China mainland declarations")
struct ChinaDeclarationTests {
    private typealias Support = ComplianceTestSupport
    private static let filing = AIFilingDetails(kind: .algorithm, number: " 网信算备110108823483901230031号 ", name: "Lumen Reflect ")
    private static let soldInChina = Support.content(sold: [ComplianceRegion.chinaMainland: [], Support.unitedStates: []])

    @Test func askedOfEveryAppSoldInChinaMainland() {
        let report = Support.report(Self.soldInChina)
        #expect(report.chinaDeclarations == .soldInChina)
        #expect(report.state(of: .securityAssessment) == .needsAnswer)
        #expect(report.state(of: .aiGeneratedContent) == .needsAnswer)
        #expect(report.detail(for: .aiGeneratedContent).contains("January 31, 2027"))
        #expect(report.detail(for: .securityAssessment).contains("end-to-end encrypted messaging"))
    }

    /// App Store Connect shows both as Missing Info even when the app
    /// isn't sold in China mainland: No is the answer to enter there.
    @Test func notSoldThereStillAskedWithNo() {
        let outside = Support.content(sold: [Support.unitedStates: []], notSold: [ComplianceRegion.chinaMainland])
        let report = Support.report(outside)
        #expect(report.chinaDeclarations == .notSoldInChina)
        #expect(report.state(of: .securityAssessment) == .toEnter)
        #expect(report.state(of: .aiGeneratedContent) == .toEnter)
        #expect(report.securityAssessmentAnswer == false)
        #expect(report.aiContentAnswer == AIContentAnswer(offersAI: false))
        #expect(report.detail(for: .securityAssessment).contains("isn’t sold in China mainland, so answer No there"))
        #expect(report.refusal(for: .aiGeneratedContent) == nil)
        #expect(Support.report(ComplianceContent(territories: nil)).chinaDeclarations == .notSoldInChina)

        let declared = Support.report(outside, answers: ComplianceAnswers(declared: [.securityAssessment]))
        #expect(declared.state(of: .securityAssessment) == .passes)
        #expect(declared.passTitle(for: .securityAssessment) == "Security Assessment · declared")
        #expect(declared.isMarkedDeclared(.securityAssessment))
    }

    /// A Yes still counts outside China mainland: the person may know
    /// better (it comes back there soon).
    @Test func aYesOutsideChinaMainlandIsKept() {
        let outside = Support.content(sold: [Support.unitedStates: []], notSold: [ComplianceRegion.chinaMainland])
        let report = Support.report(outside, answers: ComplianceAnswers(needsSecurityAssessment: true))
        #expect(report.securityAssessmentAnswer == true)
        #expect(!report.answersNoForWhereItSells(.securityAssessment))
        #expect(report.answersNoForWhereItSells(.aiGeneratedContent))
        #expect(report.detail(for: .securityAssessment).hasPrefix("Your answer:"))
    }

    @Test func aYesWithoutItsFilingStillNeedsThePerson() {
        let incomplete = Support.report(Self.soldInChina, answers: ComplianceAnswers(aiContent: AIContentAnswer(offersAI: true)))
        #expect(incomplete.state(of: .aiGeneratedContent) == .needsAnswer)
        #expect(incomplete.detail(for: .aiGeneratedContent).contains("Add the filing number"))

        let filed = Support.report(Self.soldInChina, answers: ComplianceAnswers(aiContent: AIContentAnswer(offersAI: true, filing: Self.filing)))
        #expect(filed.state(of: .aiGeneratedContent) == .toEnter)
        #expect(filed.detail(for: .aiGeneratedContent).contains("algorithm filed as “Lumen Reflect”, number 网信算备110108823483901230031号"))
    }

    @Test func anotherCompanysModelNeedsItsOwner() {
        var filing = Self.filing
        filing.usesAnotherCompanysModel = true
        #expect(!filing.isComplete)
        filing.technologyOwner = "Shanghai Mingyu Technology Co., Ltd."
        #expect(filing.isComplete)
        let report = Support.report(Self.soldInChina, answers: ComplianceAnswers(aiContent: AIContentAnswer(offersAI: true, filing: filing)))
        #expect(report.detail(for: .aiGeneratedContent).contains("Upload Shanghai Mingyu Technology Co., Ltd.’s authorization"))
    }

    @Test(arguments: [true, false])
    func eitherSecurityAnswerWaitsForAppStoreConnect(isNeeded: Bool) {
        let report = Support.report(Self.soldInChina, answers: ComplianceAnswers(needsSecurityAssessment: isNeeded))
        #expect(report.state(of: .securityAssessment) == .toEnter)
        #expect(report.detail(for: .securityAssessment).hasPrefix("Your answer:"))
    }

    @Test func markedDeclaredPassesAndOffersChange() {
        let answers = ComplianceAnswers(declared: [.securityAssessment, .aiGeneratedContent])
        let report = Support.report(Self.soldInChina, answers: answers)
        #expect(report.state(of: .securityAssessment) == .passes)
        #expect(report.isMarkedDeclared(.aiGeneratedContent))
        #expect(report.passTitle(for: .securityAssessment) == "Security Assessment · declared")
    }

    @Test func stoppingSalesThereMakesBothNo() {
        let answers = ComplianceAnswers(needsSecurityAssessment: true)
        let report = Support.report(Self.soldInChina, answers: answers, stopsSellingInChina: true)
        #expect(report.state(of: .securityAssessment) == .toEnter)
        #expect(report.state(of: .aiGeneratedContent) == .toEnter)
        #expect(report.securityAssessmentAnswer == false)
        #expect(report.detail(for: .aiGeneratedContent).contains("In App Store Connect, still answer No"))
        #expect(report.refusal(for: .aiGeneratedContent) != nil)
    }

    @Test func answersSavedBeforeTheseExistedStillLoad() throws {
        let saved = Data(#"{"addsICPNumber":true,"icpNumber":"京ICP备2024000000号-1A","declared":["medicalDevice"]}"#.utf8)
        let answers = try JSONDecoder().decode(ComplianceAnswers.self, from: saved)
        #expect(answers.aiContent == nil)
        #expect(answers.needsSecurityAssessment == nil)
        let filing = try JSONDecoder().decode(AIFilingDetails.self, from: Data(#"{"number":"1"}"#.utf8))
        #expect(filing.kind == .largeLanguageModel)
        #expect(!filing.usesAnotherCompanysModel)
    }

    @Test func theFilingIsTrimmed() {
        let trimmed = Self.filing.trimmed
        #expect(trimmed.number == "网信算备110108823483901230031号")
        #expect(trimmed.name == "Lumen Reflect")
        #expect(trimmed.technologyOwner.isEmpty)
    }
}
