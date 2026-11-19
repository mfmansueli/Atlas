//
//  ComplianceReport+Suggestions.swift
//  Atlas
//

import Foundation

// Which regulations an assistant may answer: the trader status while Apple
// has none, the ICP Filing Number while Apple asks for one, and the medical
// device question while it isn't declared, and China mainland's Security
// Assessment and AI content declarations until they're declared (Apple asks
// every app, sold there or not). The
// Vietnam game license is a number only the person has.
extension ComplianceReport {
    func takesSuggestion(for rule: ComplianceRule) -> Bool {
        refusal(for: rule) == nil
    }

    /// Why an assistant's answer for `rule` isn't taken, or nil when it is.
    func refusal(for rule: ComplianceRule) -> String? {
        switch rule {
        case .traderStatus:
            return trader == .notProvided ? nil : nothingToAnswer(rule)
        case .icpFilingNumber:
            return icp.asksForNumber ? nil : nothingToAnswer(rule)
        case .securityAssessment, .aiGeneratedContent:
            if answers.declared.contains(rule) { return String(localized: "The person already declared it in App Store Connect.") }
            return stopsSellingInChina
                ? String(localized: "The person is stopping sales in China mainland, so the answer is No.")
                : nil
        case .vietnamGameLicense:
            return String(localized: "The Vietnam game license is a number only the person has. They add it in App Store Connect.")
        case .medicalDevice:
            guard medicalDevice.isAsked else { return nothingToAnswer(rule) }
            return answers.declared.contains(.medicalDevice)
                ? String(localized: "The person already declared it in App Store Connect.")
                : nil
        }
    }

    private func nothingToAnswer(_ rule: ComplianceRule) -> String {
        String(localized: "Nothing to answer: \(detail(for: rule))")
    }
}
