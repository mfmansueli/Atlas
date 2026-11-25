//
//  ChinaAIContentCheck.swift
//  Atlas
//

import Foundation

/// China mainland's AI-generated or synthetic content declaration (App
/// Store Connect → App Compliance, November 2026). Apple's API can't read
/// it, so this reads the person's answer in Atlas (`ComplianceAnswers`):
/// sold in China mainland and unanswered, the app won't be available
/// there (apps already there have until January 31, 2027); No while the
/// app shows AI generation is likely wrong unless it's off or geoblocked
/// there; Yes needs the CAC filing; OpenAI's, Anthropic's and Google's
/// models have none. Not sold there, No is the answer.
struct ChinaAIContentCheck: ReviewRiskCheck {
    let id = ReviewRiskCheckID.chinaAIContent

    private let rule = ComplianceRule.aiGeneratedContent

    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome {
        guard let content = facts.content, let report = content.compliance else {
            return .notChecked(String(localized: "Atlas couldn’t read App Compliance.", comment: "kind:error · an App Review check that couldn’t run"))
        }
        let declared = report.answers.declared.contains(rule)
        guard content.isSoldInChina else {
            guard !declared else { return .clear }
            let title = String(localized: "AI content: answer No in App Store Connect", comment: "kind:title · an App Review risk")
            return .risks([ChinaDeclarationRisks.answerNo(check: id, rule: rule, title: title)])
        }
        let signals = ReviewRiskAISignals(facts)
        guard let answer = report.aiContentAnswer else {
            return .risks(declared ? [] : [unanswered(signals)])
        }
        guard answer.offersAI else {
            if !signals.isEmpty { return .risks([answeredNo(signals)]) }
            return .risks(declared ? [] : [enter(String(localized: "No", comment: "kind:label · a declaration's answer"))])
        }
        guard answer.filing.isComplete else { return .risks([incompleteFiling(answer.filing)]) }
        var risks: [ReviewRisk] = []
        if !signals.usProviders.isEmpty { risks.append(usProvider(signals)) }
        if !declared { risks.append(enter(String(localized: "Yes", comment: "kind:label · a declaration's answer"))) }
        return .risks(risks)
    }

    private func unanswered(_ signals: ReviewRiskAISignals) -> ReviewRisk {
        ReviewRisk(
            check: id,
            subject: "unanswered",
            level: .blocksReview,
            title: String(localized: "AI content declaration not answered", comment: "kind:title · an App Review risk"),
            why: String(
                localized: "Without it the app won’t be available in China mainland; apps there have until \(ComplianceReport.chinaDeclarationDeadline).",
                comment: "kind:why · an App Review risk"
            ),
            evidence: [ChinaDeclarationRisks.notAnswered(rule)] + ChinaDeclarationRisks.evidence(signals.signals),
            howSure: .sure,
            fix: ChinaDeclarationRisks.fix(String(
                localized: "Answer it in App Compliance and in App Store Connect: Yes with the model’s CAC filing, or No if AI is off there.",
                comment: "kind:detail · how to fix an App Review risk"
            ), rule: rule)
        )
    }

    private func answeredNo(_ signals: ReviewRiskAISignals) -> ReviewRisk {
        ReviewRisk(
            check: id,
            subject: "answeredNo",
            level: .likely,
            title: String(localized: "No AI declared, but the app has AI", comment: "kind:title · an App Review risk"),
            why: String(
                localized: "Atlas found \(ChinaDeclarationRisks.terms(signals.signals)); No is right only if AI is off or geoblocked in China mainland.",
                comment: "kind:why · an App Review risk"
            ),
            evidence: [ChinaDeclarationRisks.answer(rule, String(localized: "No", comment: "kind:label · a declaration's answer"))]
                + ChinaDeclarationRisks.evidence(signals.signals),
            howSure: .fairlySure,
            fix: ChinaDeclarationRisks.fix(String(
                localized: "If it’s off or geoblocked in China mainland, No is right; if not, answer Yes with the model’s CAC filing.",
                comment: "kind:detail · how to fix an App Review risk"
            ), rule: rule)
        )
    }

    private func incompleteFiling(_ filing: AIFilingDetails) -> ReviewRisk {
        let trimmed = filing.trimmed
        var missing: [String] = []
        if trimmed.number.isEmpty { missing.append(String(localized: "filing number", comment: "kind:label · part of a CAC filing")) }
        if trimmed.name.isEmpty { missing.append(String(localized: "registered name", comment: "kind:label · part of a CAC filing")) }
        if filing.usesAnotherCompanysModel, trimmed.technologyOwner.isEmpty {
            missing.append(String(localized: "owner", comment: "kind:label · part of a CAC filing: the company that owns the model"))
        }
        let list = missing.formatted(.list(type: .and))
        return ReviewRisk(
            check: id,
            subject: "filing",
            level: .blocksReview,
            title: String(localized: "AI filing details missing", comment: "kind:title · an App Review risk"),
            why: missing.count == 1
                ? String(
                    localized: "Yes needs the \(trimmed.kind.shortName)’s \(list); China mainland drops the app without it.",
                    comment: "kind:why · an App Review risk"
                )
                : String(
                    localized: "Yes needs the \(trimmed.kind.shortName)’s \(list); China mainland drops the app without them.",
                    comment: "kind:why · an App Review risk"
                ),
            evidence: [ChinaDeclarationRisks.answer(rule, String(localized: "Yes · missing \(list)", comment: "kind:label · a declaration's answer"))],
            howSure: .sure,
            fix: ChinaDeclarationRisks.fix(String(
                localized: "Add the filing as the Cyberspace Administration of China approved it, or stop selling in China mainland.",
                comment: "kind:detail · how to fix an App Review risk"
            ), rule: rule)
        )
    }

    private func usProvider(_ signals: ReviewRiskAISignals) -> ReviewRisk {
        ReviewRisk(
            check: id,
            subject: "usProvider",
            level: .check,
            title: String(localized: "US AI models have no China filing", comment: "kind:title · an App Review risk"),
            why: String(
                localized: "The app names \(ChinaDeclarationRisks.terms(signals.usProviders)); OpenAI, Anthropic and Google models have no CAC filing.",
                comment: "kind:why · an App Review risk"
            ),
            evidence: [ChinaDeclarationRisks.answer(rule, String(localized: "Yes", comment: "kind:label · a declaration's answer"))]
                + ChinaDeclarationRisks.evidence(signals.usProviders),
            howSure: .fairlySure,
            fix: ChinaDeclarationRisks.fix(String(
                localized: "Check the filing is for the model China mainland users reach; if it’s a US model, geoblock AI there and answer No.",
                comment: "kind:detail · how to fix an App Review risk"
            ), rule: rule)
        )
    }

    private func enter(_ answer: String) -> ReviewRisk {
        ChinaDeclarationRisks.enterInAppStoreConnect(
            check: id,
            rule: rule,
            title: String(localized: "Enter the AI content answer in App Store Connect", comment: "kind:title · an App Review risk"),
            answer: answer
        )
    }
}
