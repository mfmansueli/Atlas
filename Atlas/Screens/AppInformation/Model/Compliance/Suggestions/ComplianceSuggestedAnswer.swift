//
//  ComplianceSuggestedAnswer.swift
//  Atlas
//

import Foundation

/// What an assistant suggests for one regulation on the App Compliance
/// page. Accepting it gives the same answer as the page's own buttons;
/// only "stop selling in China mainland" becomes a change in Review &
/// Push, the rest wait to be entered in App Store Connect.
enum ComplianceSuggestedAnswer: Hashable, Codable, Sendable {
    /// Digital Services Act: a trader, with these details.
    case trader(TraderDetails)
    /// Digital Services Act: not a trader.
    case nonTrader
    /// China mainland: this ICP Filing Number.
    case icpNumber(String)
    /// China mainland: take the app off sale there.
    case stopSellingInChina
    /// Whether the app is a regulated medical device.
    case medicalDevice(isRegulated: Bool)
    /// China mainland: whether the app has features that need a Security
    /// Assessment.
    case securityAssessment(isNeeded: Bool)
    /// China mainland: whether the app offers AI-generated content, with
    /// its filing as far as the project shows it.
    case aiContent(AIContentAnswer)

    var rule: ComplianceRule {
        switch self {
        case .trader, .nonTrader: .traderStatus
        case .icpNumber, .stopSellingInChina: .icpFilingNumber
        case .medicalDevice: .medicalDevice
        case .securityAssessment: .securityAssessment
        case .aiContent: .aiGeneratedContent
        }
    }

    /// The answer in a few words, e.g. "Trader, with these details".
    var title: String {
        switch self {
        case .trader: String(localized: "Trader, with these details")
        case .nonTrader: String(localized: "Non-trader")
        case let .icpNumber(number): String(localized: "ICP Filing Number \(ICPFilingNumber.normalized(number))")
        case .stopSellingInChina: String(localized: "Stop selling in China mainland")
        case .medicalDevice(isRegulated: true): String(localized: "A regulated medical device")
        case .medicalDevice(isRegulated: false): String(localized: "Not a regulated medical device")
        case .securityAssessment(isNeeded: true): String(localized: "Needs a Security Assessment")
        case .securityAssessment(isNeeded: false): String(localized: "Nothing that needs a Security Assessment")
        case let .aiContent(answer) where answer.offersAI:
            if answer.filing.isComplete {
                String(localized: "Offers AI generation, filed as “\(answer.filing.trimmed.name)”")
            } else {
                String(localized: "Offers AI generation, filing not found")
            }
        case .aiContent: String(localized: "No AI generation in China mainland")
        }
    }

    /// Whether accepting it queues an App Store Connect change in Review &
    /// Push: only stopping sales in China mainland. The rest are kept in
    /// Atlas for the person to enter in App Store Connect.
    var isPushable: Bool {
        self == .stopSellingInChina
    }

    /// The person already gave this answer.
    func isGiven(in report: ComplianceReport) -> Bool {
        let answers = report.answers
        switch self {
        case let .trader(details):
            return answers.trader == .trader && answers.traderDetails == details
        case .nonTrader:
            return answers.trader == .nonTrader
        case let .icpNumber(number):
            return answers.addsICPNumber && ICPFilingNumber.normalized(answers.icpNumber) == ICPFilingNumber.normalized(number)
        case .stopSellingInChina:
            return report.stopsSellingInChina
        case let .medicalDevice(isRegulated):
            return answers.regulatedMedicalDevice == isRegulated
        case let .securityAssessment(isNeeded):
            return report.securityAssessmentAnswer == isNeeded
        case let .aiContent(answer):
            return report.aiContentAnswer?.offersAI == answer.offersAI
                && (!answer.offersAI || report.aiContentAnswer?.filing.trimmed == answer.filing.trimmed)
        }
    }
}
