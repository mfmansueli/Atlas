//
//  ComplianceReport+ChinaText.swift
//  Atlas
//

import Foundation

// What the App Compliance page says about China mainland's Security
// Assessment and AI-generated content declarations, from Apple's help
// ("View China mainland compliance information", November 2026).
extension ComplianceReport {
    /// Apple's deadline for apps already on the App Store in China
    /// mainland.
    static let chinaDeclarationDeadline = String(localized: "January 31, 2027")

    var securityAssessmentDetail: String {
        if let common = chinaDetail(for: .securityAssessment) { return common }
        switch securityAssessmentAnswer {
        case true?:
            return String(localized: "Your answer: \(appName) needs a Security Assessment. In App Store Connect, add the screenshot showing it passed and the sealed report, then mark it as declared.")
        case false?:
            return String(localized: "Your answer: \(appName) has nothing that needs a Security Assessment. Answer No in App Store Connect, then mark it as declared.")
        case nil:
            return String(localized: "Apple asks every app whether it has features that need a Security Assessment in China mainland, such as sharing AI-generated content or end-to-end encrypted messaging. Apps already there have until \(Self.chinaDeclarationDeadline).")
        }
    }

    var aiContentDetail: String {
        if let common = chinaDetail(for: .aiGeneratedContent) { return common }
        guard let answer = aiContentAnswer else {
            return String(localized: "In China mainland, Apple asks if the app offers AI generation or synthetic content: chatbots, image or video, voice or face changes. Yes needs an approved filing. Apps there have until \(Self.chinaDeclarationDeadline).")
        }
        guard answer.offersAI else {
            return String(localized: "Your answer: \(appName) doesn’t offer AI generation in China mainland. Answer No in App Store Connect, then mark it as declared.")
        }
        let filing = answer.filing.trimmed
        guard answer.filing.isComplete else {
            return String(localized: "Your answer: \(appName) offers AI generation. Add the filing number and registered name of its \(filing.kind.shortName), as the Cyberspace Administration of China approved them, or stop selling in China mainland.")
        }
        let base = String(localized: "Your answer: \(appName) offers AI generation, with the \(filing.kind.shortName) filed as “\(filing.name)”, number \(filing.number).")
        let owner = filing.usesAnotherCompanysModel
            ? " " + String(localized: "Upload \(filing.technologyOwner)’s authorization or usage agreement too: it names the model and its filing number, you as the authorized party, and \(filing.technologyOwner) as in the CAC’s registry.")
            : ""
        return base + owner + " " + String(localized: "Enter it in App Store Connect, then mark it as declared.")
    }

    /// What both say when it's declared, or when No comes from where the
    /// app is sold: App Store Connect asks even when it isn't sold there.
    private func chinaDetail(for rule: ComplianceRule) -> String? {
        if answers.declared.contains(rule) { return String(localized: "You marked it as declared in App Store Connect.") }
        guard answersNoForWhereItSells(rule) else { return nil }
        if stopsSellingInChina {
            return String(localized: "China mainland comes off \(appName)’s availability when you push. In App Store Connect, still answer No, then mark it as declared.")
        }
        return String(localized: "App Store Connect asks every app. \(appName) isn’t sold in China mainland, so answer No there, then mark it as declared.")
    }
}
