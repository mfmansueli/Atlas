//
//  ComplianceReport.swift
//  Atlas
//

import Foundation

/// The App Compliance page worked out for one app: what each regulation
/// asks, from where the app is sold, its categories, its age rating and
/// Apple's notes per country, with the person's answers on top.
///
/// Nothing here answers for the person: a regulation Apple asks about
/// stays "needs you" until they decide, or accept an assistant's answer.
struct ComplianceReport: Hashable, Sendable {
    var appName: String
    var trader: TraderCheck
    var icp: ICPCheck
    var gameLicense: GameLicenseCheck
    var medicalDevice: MedicalDeviceCheck
    /// China mainland's AI content and Security Assessment declarations.
    var chinaDeclarations: ChinaDeclarationCheck
    var answers: ComplianceAnswers
    /// "Stop selling in China mainland" waits in Review & Push.
    var stopsSellingInChina: Bool
    /// The app sells subscriptions or in-app purchases; nil when that
    /// isn't known yet.
    var sellsInApp: Bool?
    /// The primary category's ID, for the lines that name it.
    var primaryCategory: String?

    init(
        appName: String,
        content: ComplianceContent,
        general: GeneralValues,
        ageRating: AgeRatingAnswers,
        answers: ComplianceAnswers = ComplianceAnswers(),
        stopsSellingInChina: Bool = false,
        sellsInApp: Bool? = nil
    ) {
        self.appName = appName
        trader = TraderCheck(content)
        icp = ICPCheck(content)
        gameLicense = GameLicenseCheck(content, general: general)
        medicalDevice = MedicalDeviceCheck(content, general: general, ageRating: ageRating)
        chinaDeclarations = ChinaDeclarationCheck(content)
        self.answers = answers
        self.stopsSellingInChina = stopsSellingInChina
        self.sellsInApp = sellsInApp
        primaryCategory = general.primaryCategory
    }

    // MARK: - States

    func state(of rule: ComplianceRule) -> ComplianceItemState {
        switch rule {
        case .traderStatus: traderState
        case .icpFilingNumber: icpState
        case .securityAssessment: chinaState(answered: securityAssessmentAnswer != nil, rule: rule)
        case .aiGeneratedContent: chinaState(answered: aiContentAnswer?.isComplete == true, rule: rule)
        case .vietnamGameLicense: gameLicenseState
        case .medicalDevice: medicalDeviceState
        }
    }

    private var traderState: ComplianceItemState {
        switch trader {
        case .noCountriesYet, .notSoldInEU, .declared: .passes
        case .notProvided: answers.trader == nil ? .needsAnswer : .toEnter
        case .verificationFailed, .verificationMissing: .needsAnswer
        }
    }

    private var icpState: ComplianceItemState {
        guard icp.asksForNumber else { return .passes }
        if stopsSellingInChina { return .notPushed }
        return answers.hasValidICPNumber ? .toEnter : .needsAnswer
    }

    /// Asked of every app, sold in China mainland or not: it needs a
    /// complete answer, then the person marks it as declared in App Store
    /// Connect.
    private func chinaState(answered: Bool, rule: ComplianceRule) -> ComplianceItemState {
        guard !answers.declared.contains(rule) else { return .passes }
        return answered ? .toEnter : .needsAnswer
    }

    /// No unless it's sold in China mainland and stays there: Apple says
    /// to answer No when the features are off or geoblocked there, which
    /// an app not sold there is.
    var answersNoInChina: Bool {
        !chinaDeclarations.isSoldThere || stopsSellingInChina
    }

    /// The Security Assessment's answer: No when it isn't sold in China
    /// mainland (unless the person said Yes) or is stopping sales there,
    /// else the person's.
    var securityAssessmentAnswer: Bool? {
        if stopsSellingInChina { return false }
        return answers.needsSecurityAssessment ?? (answersNoInChina ? false : nil)
    }

    /// The AI content declaration's answer, the same way.
    var aiContentAnswer: AIContentAnswer? {
        if stopsSellingInChina { return AIContentAnswer(offersAI: false) }
        return answers.aiContent ?? (answersNoInChina ? AIContentAnswer(offersAI: false) : nil)
    }

    /// The answer is No because of where it's sold, not the person's.
    func answersNoForWhereItSells(_ rule: ComplianceRule) -> Bool {
        if stopsSellingInChina { return true }
        guard answersNoInChina else { return false }
        return switch rule {
        case .securityAssessment: answers.needsSecurityAssessment == nil
        case .aiGeneratedContent: answers.aiContent == nil
        default: false
        }
    }

    private var gameLicenseState: ComplianceItemState {
        switch gameLicense {
        case .notAGame, .notSoldInVietnam: .passes
        case .needed: answers.declared.contains(.vietnamGameLicense) ? .passes : .needsAnswer
        case .flaggedByApple: .needsAnswer
        }
    }

    private var medicalDeviceState: ComplianceItemState {
        guard medicalDevice.isAsked else { return .passes }
        if answers.declared.contains(.medicalDevice) { return .passes }
        return answers.regulatedMedicalDevice == nil ? .needsAnswer : .toEnter
    }

    // MARK: - Counts

    private func count(_ state: ComplianceItemState) -> Int {
        ComplianceRule.allCases.count { self.state(of: $0) == state }
    }

    /// Regulations waiting for the person's answer.
    var needCount: Int { count(.needsAnswer) }

    /// Answered here, still to be entered in App Store Connect.
    var toEnterCount: Int { count(.toEnter) }

    /// Not needed, or fine at Apple.
    var passCount: Int { count(.passes) }

    /// Nothing left for the person, here or in App Store Connect.
    var isUpToDate: Bool { needCount == 0 && toEnterCount == 0 }

    // MARK: - Trader suggestion

    /// The built-in check suggests "trader": the app sells something in the
    /// EU and Apple has no status. The person still decides.
    var suggestsTrader: Bool {
        trader == .notProvided && answers.trader == nil && sellsInApp == true
    }
}
