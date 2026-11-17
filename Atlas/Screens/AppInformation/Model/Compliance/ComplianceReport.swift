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
/// stays "needs you" until they decide.
struct ComplianceReport: Hashable, Sendable {
    var appName: String
    var trader: TraderCheck
    var icp: ICPCheck
    var gameLicense: GameLicenseCheck
    var medicalDevice: MedicalDeviceCheck
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

    private var gameLicenseState: ComplianceItemState {
        switch gameLicense {
        case .notAGame, .notSoldInVietnam: .passes
        case .needed: answers.declared.contains(.vietnamGameLicense) ? .passes : .needsAnswer
        case .flaggedByApple: .needsAnswer
        }
    }

    private var medicalDeviceState: ComplianceItemState {
        guard medicalDevice.isAsked else { return .passes }
        return answers.declared.contains(.medicalDevice) ? .passes : .needsAnswer
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
