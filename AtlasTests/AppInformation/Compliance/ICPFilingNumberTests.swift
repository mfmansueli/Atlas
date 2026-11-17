//
//  ICPFilingNumberTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The ICP Filing Number's format check.
@Suite("ICPFilingNumber")
struct ICPFilingNumberTests {
    @Test(arguments: [
        "京ICP备2024000000号-1A", "沪ICP备2026012345号-2A", "粤ICP备12345678号", "京ICP备12345678号-12", " 京ICP备 2024000000号-1A ",
    ])
    func numbersThatReadRightPass(number: String) {
        #expect(ICPFilingNumber.isValid(number))
    }

    @Test(arguments: [
        "", "ICP备2024000000号-1A", "京ICP备1234号", "京ICP2024000000号", "京ICP备2024000000", "AICP备2024000000号-1A", "京ICP备2024000000号-", "12345678",
    ])
    func anythingElseDoesNot(number: String) {
        #expect(!ICPFilingNumber.isValid(number))
    }

    @Test func theExampleItselfIsValid() {
        #expect(ICPFilingNumber.isValid(ICPFilingNumber.example))
    }

    @Test func aCopiedNumberLosesItsSpaces() {
        #expect(ICPFilingNumber.normalized(" 京ICP备 2024000000号-1A\n") == "京ICP备2024000000号-1A")
    }

    @Test func theAnswersSayWhetherATypedNumberReadsRight() {
        var answers = ComplianceAnswers(addsICPNumber: true, icpNumber: "")
        #expect(!answers.hasValidICPNumber)
        #expect(!answers.hasMalformedICPNumber)

        answers.icpNumber = "京ICP"
        #expect(!answers.hasValidICPNumber)
        #expect(answers.hasMalformedICPNumber)

        answers.icpNumber = ICPFilingNumber.example
        #expect(answers.hasValidICPNumber)
        #expect(!answers.hasMalformedICPNumber)

        answers.addsICPNumber = false
        #expect(!answers.hasValidICPNumber)
    }
}
