//
//  ChinaSecurityAssessmentCheck.swift
//  Atlas
//

import Foundation

/// China mainland's Security Assessment declaration (App Store Connect →
/// App Compliance, November 2026): whether the app has features that need
/// one, such as people posting, chatting or streaming to each other,
/// sharing AI-generated content, or end-to-end encrypted messaging.
/// Apple's API can't read it, so this reads the person's answer in Atlas:
/// sold in China mainland and unanswered, the app won't be available there
/// (apps already there have until January 31, 2027); No while those
/// features show is likely wrong unless they're off there; Yes needs two
/// uploads in App Store Connect. Not sold there, No is the answer.
struct ChinaSecurityAssessmentCheck: ReviewRiskCheck {
    let id = ReviewRiskCheckID.chinaSecurityAssessment

    private let rule = ComplianceRule.securityAssessment

    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome {
        guard let content = facts.content, let report = content.compliance else {
            return .notChecked(String(localized: "Atlas couldn’t read App Compliance.", comment: "kind:error · an App Review check that couldn’t run"))
        }
        let declared = report.answers.declared.contains(rule)
        guard content.isSoldInChina else {
            guard !declared else { return .clear }
            let title = String(localized: "Security Assessment: answer No in App Store Connect", comment: "kind:title · an App Review risk")
            return .risks([ChinaDeclarationRisks.answerNo(check: id, rule: rule, title: title)])
        }
        let needs = Self.featuresNeedingAssessment(facts)
        switch report.securityAssessmentAnswer {
        case nil:
            return .risks(declared ? [] : [unanswered(needs)])
        case false?:
            if !needs.isEmpty { return .risks([answeredNo(needs)]) }
            return .risks(declared ? [] : [enter(String(localized: "No", comment: "kind:label · a declaration's answer"))])
        case true?:
            return .risks(declared ? [] : [uploads()])
        }
    }

    /// People reaching each other (dating, messaging, a community, live
    /// streams), end-to-end encrypted messages, or AI content that people
    /// share. Empty when none shows.
    static func featuresNeedingAssessment(_ facts: ReviewRiskFacts) -> [ReviewRiskSignal] {
        let social = ReviewRiskSocialSignals(facts)
        var found = social.encryptedMessaging + social.strong
        let ai = ReviewRiskAISignals(facts)
        if found.isEmpty, !ai.generation.isEmpty, !social.sharing.isEmpty {
            found = Array(ai.generation.prefix(1)) + social.sharing
        }
        return found
    }

    private func unanswered(_ needs: [ReviewRiskSignal]) -> ReviewRisk {
        ReviewRisk(
            check: id,
            subject: "unanswered",
            level: .blocksReview,
            title: String(localized: "Security Assessment not answered", comment: "kind:title · an App Review risk"),
            why: String(
                localized: "Without it the app won’t be available in China mainland; apps there have until \(ComplianceReport.chinaDeclarationDeadline).",
                comment: "kind:why · an App Review risk"
            ),
            evidence: [ChinaDeclarationRisks.notAnswered(rule)] + ChinaDeclarationRisks.evidence(needs),
            howSure: .sure,
            fix: ChinaDeclarationRisks.fix(String(
                localized: "Answer it in App Compliance and in App Store Connect: Yes with the assessment, or No if nothing needs one.",
                comment: "kind:detail · how to fix an App Review risk"
            ), rule: rule)
        )
    }

    private func answeredNo(_ needs: [ReviewRiskSignal]) -> ReviewRisk {
        ReviewRisk(
            check: id,
            subject: "answeredNo",
            level: .likely,
            title: String(localized: "Security Assessment may be needed", comment: "kind:title · an App Review risk"),
            why: String(
                localized: "Atlas found \(ChinaDeclarationRisks.terms(needs)): features like these need an assessment in China mainland.",
                comment: "kind:why · an App Review risk"
            ),
            evidence: [ChinaDeclarationRisks.answer(rule, String(localized: "No", comment: "kind:label · a declaration's answer"))]
                + ChinaDeclarationRisks.evidence(needs),
            howSure: .fairlySure,
            fix: ChinaDeclarationRisks.fix(String(
                localized: "If these features are off or geoblocked in China mainland, No is right; if not, pass the assessment and answer Yes.",
                comment: "kind:detail · how to fix an App Review risk"
            ), rule: rule)
        )
    }

    private func uploads() -> ReviewRisk {
        ReviewRisk(
            check: id,
            subject: "uploads",
            level: .check,
            title: String(localized: "Upload the Security Assessment files", comment: "kind:title · an App Review risk"),
            why: String(
                localized: "Yes takes 2 uploads in App Store Connect: proof the app passed, and the report with its seal.",
                comment: "kind:why · an App Review risk"
            ),
            evidence: [ChinaDeclarationRisks.answer(rule, String(localized: "Yes", comment: "kind:label · a declaration's answer"))],
            howSure: .sure,
            fix: ReviewRiskFix(advice: String(
                localized: "Upload both on App Store Connect’s App Compliance page, then mark it as declared in Atlas.",
                comment: "kind:detail · how to fix an App Review risk"
            ))
        )
    }

    private func enter(_ answer: String) -> ReviewRisk {
        ChinaDeclarationRisks.enterInAppStoreConnect(
            check: id,
            rule: rule,
            title: String(localized: "Enter Security Assessment answer in App Store Connect", comment: "kind:title · an App Review risk"),
            answer: answer
        )
    }
}
