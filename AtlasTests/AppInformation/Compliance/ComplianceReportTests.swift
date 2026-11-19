//
//  ComplianceReportTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What each regulation asks, from where the app is sold, its categories,
/// its age rating and Apple's statuses, with the person's answers on top.
@Suite("ComplianceReport")
struct ComplianceReportTests {
    private typealias Support = ComplianceTestSupport

    // MARK: - Digital Services Act

    @Test func noTraderStatusAtAppleNeedsThePerson() {
        let content = Support.content(sold: [Support.germany: [ComplianceContent.traderNotProvided, "CANNOT_SELL"], Support.unitedStates: []])
        let report = Support.report(content)
        #expect(report.trader == .notProvided)
        #expect(report.state(of: .traderStatus) == .needsAnswer)
        #expect(report.needCount == 1)
        #expect(report.status == "1 needs you")
    }

    @Test(arguments: [TraderDecision.trader, .nonTrader])
    func aDecisionStillHasToBeEnteredInAppStoreConnect(decision: TraderDecision) {
        let content = Support.content(sold: [Support.germany: [ComplianceContent.traderNotProvided]])
        // China mainland's two declarations are asked of every app: declared here.
        let report = Support.report(content, answers: ComplianceAnswers(trader: decision, declared: [.securityAssessment, .aiGeneratedContent]))
        #expect(report.state(of: .traderStatus) == .toEnter)
        #expect(report.needCount == 0)
        #expect(report.toEnterCount == 1)
        #expect(!report.isUpToDate)
        #expect(report.status == "1 to finish at Apple")
    }

    @Test func soldInTheEUWithNothingMissingIsDeclared() {
        let report = Support.report()
        #expect(report.trader == .declared)
        #expect(report.state(of: .traderStatus) == .passes)
        #expect(report.passTitle(for: .traderStatus) == "Digital Services Act · declared")
    }

    @Test func notSoldInTheEUIsNotAsked() {
        let content = Support.content(sold: [Support.unitedStates: []], notSold: [Support.germany])
        let report = Support.report(content)
        #expect(report.trader == .notSoldInEU)
        #expect(report.state(of: .traderStatus) == .passes)
        #expect(report.passTitle(for: .traderStatus) == "Digital Services Act · not needed")
    }

    @Test func aStatusOnACountryTheAppIsNotSoldInIsIgnored() {
        var content = Support.content(sold: [Support.unitedStates: []], notSold: [Support.germany])
        content.territories?[0].statuses = [ComplianceContent.traderNotProvided]
        #expect(content.territories?[0].territoryID == Support.germany)
        #expect(Support.report(content).trader == .notSoldInEU)
    }

    @Test(arguments: [
        (ComplianceContent.traderVerificationFailed, TraderCheck.verificationFailed),
        (ComplianceContent.traderVerificationMissing, TraderCheck.verificationMissing),
    ])
    func detailsAppleCouldNotVerifyNeedThePersonWhateverTheyAnsweredHere(status: String, check: TraderCheck) {
        let content = Support.content(sold: [Support.germany: [status]])
        let report = Support.report(content, answers: ComplianceAnswers(trader: .trader))
        #expect(report.trader == check)
        #expect(report.state(of: .traderStatus) == .needsAnswer)
    }

    @Test func traderIsSuggestedOnlyWhenTheAppSellsSomething() {
        let content = Support.content(sold: [Support.germany: [ComplianceContent.traderNotProvided]])
        #expect(Support.report(content, sellsInApp: true).suggestsTrader)
        #expect(!Support.report(content, sellsInApp: false).suggestsTrader)
        #expect(!Support.report(content, sellsInApp: nil).suggestsTrader)
        #expect(!Support.report(content, answers: ComplianceAnswers(trader: .nonTrader), sellsInApp: true).suggestsTrader)
        #expect(!Support.report(sellsInApp: true).suggestsTrader)
    }

    // MARK: - ICP Filing Number

    @Test(arguments: [(ComplianceContent.icpMissing, ICPCheck.missing), (ComplianceContent.icpInvalid, ICPCheck.invalid)])
    func aMissingOrInvalidNumberNeedsThePerson(status: String, check: ICPCheck) {
        let report = Support.report(Support.content(sold: [ComplianceRegion.chinaMainland: [status]]))
        #expect(report.icp == check)
        #expect(report.state(of: .icpFilingNumber) == .needsAnswer)
    }

    @Test func aNumberThatReadsRightWaitsForAppStoreConnect() {
        let content = Support.content(sold: [ComplianceRegion.chinaMainland: [ComplianceContent.icpMissing]])
        let typed = ComplianceAnswers(addsICPNumber: true, icpNumber: "沪ICP备2026012345号-2A")
        #expect(Support.report(content, answers: typed).state(of: .icpFilingNumber) == .toEnter)

        let malformed = ComplianceAnswers(addsICPNumber: true, icpNumber: "ICP 123")
        #expect(Support.report(content, answers: malformed).state(of: .icpFilingNumber) == .needsAnswer)

        let notChosen = ComplianceAnswers(addsICPNumber: false, icpNumber: "沪ICP备2026012345号-2A")
        #expect(Support.report(content, answers: notChosen).state(of: .icpFilingNumber) == .needsAnswer)
    }

    @Test func stoppingSalesInChinaIsAChangeNotPushed() {
        let content = Support.content(sold: [ComplianceRegion.chinaMainland: [ComplianceContent.icpMissing]])
        let report = Support.report(content, stopsSellingInChina: true)
        #expect(report.state(of: .icpFilingNumber) == .notPushed)
        #expect(report.needCount == 0)
        // App Store Connect still asks the two declarations: No, to enter there.
        #expect(report.toEnterCount == 2)
        let declared = Support.report(content, answers: ComplianceAnswers(declared: [.securityAssessment, .aiGeneratedContent]), stopsSellingInChina: true)
        #expect(declared.isUpToDate)
    }

    @Test func notSoldInChinaOrNothingMissingPasses() {
        let notSold = Support.report(Support.content(sold: [Support.unitedStates: []], notSold: [ComplianceRegion.chinaMainland]))
        #expect(notSold.icp == .notSoldInChina)
        #expect(notSold.passTitle(for: .icpFilingNumber) == "ICP Filing Number · not needed")

        let fine = Support.report()
        #expect(fine.icp == .noProblem)
        #expect(fine.state(of: .icpFilingNumber) == .passes)
        #expect(fine.passTitle(for: .icpFilingNumber) == "ICP Filing Number · nothing missing")
    }

    @Test func aCountryAppleIsStillTakingOffSaleNoLongerCounts() {
        let leaving: Set<String> = [ComplianceContent.icpMissing, ComplianceTerritory.leavingStatus]
        let content = Support.content(sold: [ComplianceRegion.chinaMainland: leaving, Support.unitedStates: []])
        let report = Support.report(content)
        #expect(report.icp == .notSoldInChina)
        #expect(report.state(of: .icpFilingNumber) == .passes)
    }

    // MARK: - Vietnam Game License

    @Test func anAppThatIsNotAGameNeedsNoLicense() {
        let report = Support.report()
        #expect(report.gameLicense == .notAGame)
        #expect(report.state(of: .vietnamGameLicense) == .passes)
        #expect(report.detail(for: .vietnamGameLicense) == "Lumen isn’t a game (category: Lifestyle), so it doesn’t need a Vietnam game license.")
    }

    @Test(arguments: [("GAMES", nil), ("ENTERTAINMENT", "GAMES")] as [(String, String?)])
    func aGameSoldInVietnamNeedsItUntilThePersonSaysItIsAdded(primary: String, secondary: String?) {
        let open = Support.report(primary: primary, secondary: secondary)
        #expect(open.gameLicense == .needed)
        #expect(open.state(of: .vietnamGameLicense) == .needsAnswer)

        let marked = Support.report(primary: primary, secondary: secondary, answers: ComplianceAnswers(declared: [.vietnamGameLicense]))
        #expect(marked.state(of: .vietnamGameLicense) == .passes)
        #expect(marked.isMarkedDeclared(.vietnamGameLicense))
        #expect(marked.passTitle(for: .vietnamGameLicense) == "Vietnam Game License · declared")
    }

    @Test func aGameNotSoldInVietnamNeedsNone() {
        let content = Support.content(sold: [Support.unitedStates: []], notSold: [ComplianceRegion.vietnam])
        let report = Support.report(content, primary: "GAMES")
        #expect(report.gameLicense == .notSoldInVietnam)
        #expect(report.state(of: .vietnamGameLicense) == .passes)
    }

    @Test func appleSayingTheNumberIsMissingOutweighsTheMark() {
        let content = Support.content(sold: [ComplianceRegion.vietnam: ["MISSING_GRN"]])
        let report = Support.report(content, primary: "GAMES", answers: ComplianceAnswers(declared: [.vietnamGameLicense]))
        #expect(report.gameLicense == .flaggedByApple)
        #expect(report.state(of: .vietnamGameLicense) == .needsAnswer)
        #expect(!report.isMarkedDeclared(.vietnamGameLicense))
    }

    // MARK: - Regulated Medical Devices

    @Test func otherCategoriesWithoutFrequentMedicalInformationDeclareNothing() {
        let report = Support.report(medical: .infrequent)
        #expect(report.medicalDevice == .notNeeded)
        #expect(report.state(of: .medicalDevice) == .passes)
        #expect(report.passTitle(for: .medicalDevice) == "Regulated Medical Devices · not needed")
    }

    @Test(arguments: [("MEDICAL", nil), ("HEALTH_AND_FITNESS", nil), ("LIFESTYLE", "HEALTH_AND_FITNESS"), ("LIFESTYLE", "MEDICAL")] as [(String, String?)])
    func aMedicalOrHealthCategoryAsksForTheDeclaration(primary: String, secondary: String?) {
        let report = Support.report(primary: primary, secondary: secondary)
        #expect(report.medicalDevice == .category(secondary ?? primary))
        #expect(report.state(of: .medicalDevice) == .needsAnswer)
    }

    @Test func frequentMedicalInformationAsksForTheDeclaration() {
        let report = Support.report(medical: .frequent)
        #expect(report.medicalDevice == .frequentMedicalInformation)
        #expect(report.state(of: .medicalDevice) == .needsAnswer)
    }

    @Test func theDeclarationOnlyAppliesInTheEEATheUKAndTheUS() {
        let content = Support.content(sold: [Support.brazil: []], notSold: [Support.germany, Support.unitedStates])
        let report = Support.report(content, primary: "MEDICAL")
        #expect(report.medicalDevice == .notSoldThere)
        #expect(report.state(of: .medicalDevice) == .passes)
    }

    @Test func markingItDeclaredSettlesIt() {
        let report = Support.report(primary: "MEDICAL", answers: ComplianceAnswers(declared: [.medicalDevice]))
        #expect(report.state(of: .medicalDevice) == .passes)
        #expect(report.isMarkedDeclared(.medicalDevice))
        #expect(report.detail(for: .medicalDevice) == "You marked it as declared in App Store Connect.")
    }

    @Test func aMarkOnARuleThatIsNotAskedIsNotShownAsOne() {
        let report = Support.report(answers: ComplianceAnswers(declared: [.medicalDevice, .vietnamGameLicense]))
        #expect(!report.isMarkedDeclared(.medicalDevice))
        #expect(!report.isMarkedDeclared(.vietnamGameLicense))
    }

    // MARK: - The page

    @Test func anAppWithoutCountriesYetOnlyAsksWhatItsCategorySays() {
        let none = ComplianceContent(territories: nil)
        let plain = Support.report(none)
        #expect(plain.trader == .noCountriesYet)
        #expect(plain.icp == .noCountriesYet)
        #expect(plain.needCount == 0)
        // Only China mainland's two declarations, answered No.
        #expect(plain.status == "2 to finish at Apple")
        #expect(plain.passTitle(for: .traderStatus) == "Digital Services Act · no countries yet")

        let medical = Support.report(none, primary: "MEDICAL")
        #expect(medical.state(of: .medicalDevice) == .needsAnswer)
        let game = Support.report(none, primary: "GAMES")
        #expect(game.state(of: .vietnamGameLicense) == .needsAnswer)
    }

    @Test func theHeadlineCountsWhatNeedsThePersonWhatIsLeftForAppleAndWhatPasses() {
        let content = Support.content(sold: [
            Support.germany: [ComplianceContent.traderNotProvided],
            ComplianceRegion.chinaMainland: [ComplianceContent.icpMissing],
        ])
        // Sold in China mainland: the ICP Filing Number, the Security
        // Assessment and the AI content declaration.
        let open = Support.report(content)
        #expect(open.status == "4 need you")
        #expect(open.headline == "4 need your answer · 2 checked")

        let answers = ComplianceAnswers(
            trader: .trader,
            addsICPNumber: true,
            icpNumber: "京ICP备2024000000号-1A",
            aiContent: AIContentAnswer(offersAI: false),
            needsSecurityAssessment: false
        )
        let answered = Support.report(content, answers: answers)
        #expect(answered.status == "4 to finish at Apple")
        #expect(answered.headline == "4 to enter in App Store Connect · 2 checked")

        let declared = ComplianceAnswers(declared: [.securityAssessment, .aiGeneratedContent])
        #expect(Support.report(answers: declared).headline == "Everything answered or checked")
    }
}
