//
//  AppInformationNeedsYouTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// What only the person can give on each page ("2 need you"): empty
/// fields Apple requires, unanswered questions, compliance answers and
/// App Privacy's worksheet.
@Suite("AppInformationNeedsYou")
struct AppInformationNeedsYouTests {
    /// App Review details with every contact field filled.
    private let filledReview = AppReviewValues(firstName: "Ana", lastName: "Ribeiro", phone: "+39 011 555 0142", email: "review@northpier.dev")
    private let complete = GeneralValues(primaryCategory: "LIFESTYLE", contentRights: .doesNotUseThirdPartyContent, copyright: "© 2026 Northpier Studio")

    @Test func generalNeedsACategoryContentRightsAndACopyright() {
        #expect(AppInformationNeedsYou.general(complete, asksCopyright: true) == 0)
        #expect(AppInformationNeedsYou.general(GeneralValues(), asksCopyright: true) == 3)
        // A version that can't change any more doesn't ask for its copyright.
        #expect(AppInformationNeedsYou.general(GeneralValues(), asksCopyright: false) == 2)
        var blank = complete
        blank.copyright = "  "
        #expect(AppInformationNeedsYou.general(blank, asksCopyright: true) == 1)
    }

    @Test func thirdPartyContentNeedsTheRightsConfirmed() {
        var values = complete
        values.contentRights = .usesThirdPartyContent
        #expect(AppInformationNeedsYou.general(values, asksCopyright: true) == 1)
        values.rightsConfirmed = true
        #expect(AppInformationNeedsYou.general(values, asksCopyright: true) == 0)
    }

    @Test func appReviewCountsEmptyContactFieldsAndTheDemoAccount() {
        var review = filledReview
        #expect(AppInformationNeedsYou.review(review) == 0)
        review.phone = ""
        review.email = " "
        #expect(AppInformationNeedsYou.review(review) == 2)
        review.signInRequired = true
        #expect(AppInformationNeedsYou.review(review) == 4)
        review.userName = "review@northpier.dev"
        review.password = "sandbox"
        #expect(AppInformationNeedsYou.review(review) == 2)
    }

    @Test func exportComplianceNeedsEncryptionAnswered() {
        #expect(AppInformationNeedsYou.export(ExportComplianceAnswers()) == 1)
        #expect(AppInformationNeedsYou.export(ExportComplianceAnswers(answers: [.usesEncryption: true])) == 1)
        #expect(AppInformationNeedsYou.export(ExportComplianceAnswers(answers: [.usesEncryption: false])) == 0)
        #expect(AppInformationNeedsYou.export(ExportComplianceAnswers(usesNonExemptEncryption: false)) == 0)
    }

    @Test func complianceCountsAnswersThenWhatIsLeftForAppStoreConnect() {
        #expect(AppInformationNeedsYou.compliance(needCount: 5, toEnterCount: 1) == 5)
        #expect(AppInformationNeedsYou.compliance(needCount: 0, toEnterCount: 3) == 3)
        #expect(AppInformationNeedsYou.compliance(needCount: 0, toEnterCount: 0) == 0)
    }

    @Test func appPrivacyNeedsYouUntilItIsPublished() {
        #expect(AppInformationNeedsYou.privacy(status: .notStarted, openQuestions: 0, unreviewed: 0) == 1)
        #expect(AppInformationNeedsYou.privacy(status: .inProgress, openQuestions: 2, unreviewed: 3) == 5)
        #expect(AppInformationNeedsYou.privacy(status: .done, openQuestions: 0, unreviewed: 0) == 1)
        #expect(AppInformationNeedsYou.privacy(status: .outOfDate(.now), openQuestions: 0, unreviewed: 0) == 1)
        #expect(AppInformationNeedsYou.privacy(status: .published(.now), openQuestions: 0, unreviewed: 0) == 0)
    }
}
