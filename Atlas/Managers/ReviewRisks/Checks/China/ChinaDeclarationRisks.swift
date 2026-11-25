//
//  ChinaDeclarationRisks.swift
//  Atlas
//

import Foundation

/// What China mainland's two declarations (AI-generated content, the
/// Security Assessment) share: App Store Connect asks every app, its API
/// shows neither question nor answer, and the person marks each one as
/// declared in Atlas once it's entered there. Apple's help: answer No
/// when the features are off or geoblocked in China mainland; apps
/// already there have until January 31, 2027.
enum ChinaDeclarationRisks {
    /// The declaration's card on App Compliance, as the place of evidence.
    static func place(_ rule: ComplianceRule) -> String {
        String(localized: "App Compliance · \(rule.title)", comment: "kind:label · where an App Review risk shows: a China mainland declaration")
    }

    static func notAnswered(_ rule: ComplianceRule) -> ReviewRiskEvidence {
        ReviewRiskEvidence(place: place(rule), excerpt: String(localized: "Not answered", comment: "kind:label · a declaration with no answer"))
    }

    static func answer(_ rule: ComplianceRule, _ text: String) -> ReviewRiskEvidence {
        ReviewRiskEvidence(place: place(rule), excerpt: text)
    }

    /// The assistant's tool for the answer: `propose_compliance_answers`
    /// with the rule.
    static func fix(_ advice: String, rule: ComplianceRule) -> ReviewRiskFix {
        ReviewRiskFix(advice: advice, tool: "propose_compliance_answers", arguments: ["rule": rule.rawValue])
    }

    /// Not sold in China mainland and not marked as declared: No is the
    /// answer, and App Store Connect still shows it as missing.
    static func answerNo(check: ReviewRiskCheckID, rule: ComplianceRule, title: String) -> ReviewRisk {
        ReviewRisk(
            check: check,
            subject: "notSoldAnswerNo",
            level: .check,
            title: title,
            why: String(
                localized: "App Store Connect asks every app; it isn’t sold in China mainland, so No is the answer.",
                comment: "kind:why · an App Review risk: a China mainland declaration for an app not sold there"
            ),
            evidence: [notAnswered(rule)],
            howSure: .sure,
            fix: ReviewRiskFix(advice: String(
                localized: "Answer No on App Store Connect’s App Compliance page, then mark it as declared in Atlas.",
                comment: "kind:detail · how to fix an App Review risk"
            ))
        )
    }

    /// Answered in Atlas, not marked as declared: Apple's API can't take
    /// it, so it still has to be entered in App Store Connect.
    static func enterInAppStoreConnect(check: ReviewRiskCheckID, rule: ComplianceRule, title: String, answer: String) -> ReviewRisk {
        ReviewRisk(
            check: check,
            subject: "notEntered",
            level: .check,
            title: title,
            why: String(
                localized: "Apple’s API can’t take it; apps in China mainland need it by \(ComplianceReport.chinaDeclarationDeadline).",
                comment: "kind:why · an App Review risk: a China mainland declaration answered in Atlas only"
            ),
            evidence: [self.answer(rule, answer)],
            howSure: .fairlySure,
            fix: ReviewRiskFix(advice: String(
                localized: "Enter it on App Store Connect’s App Compliance page, then mark it as declared in Atlas.",
                comment: "kind:detail · how to fix an App Review risk"
            ))
        )
    }

    static func evidence(_ signals: [ReviewRiskSignal]) -> [ReviewRiskEvidence] {
        ReviewRiskSignal.evidence(signals)
    }

    static func terms(_ signals: [ReviewRiskSignal]) -> String {
        ReviewRiskSignal.terms(signals)
    }
}
