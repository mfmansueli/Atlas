//
//  AgeRatingCheck.swift
//  Atlas
//

import Foundation

/// 2.3.6: the age rating answers against what the app says it does. A
/// question App Store Connect has no answer for stops the submission;
/// store texts or the project that show dating, chat, a community, ads,
/// casino games, a web browser or health topics while the answer says
/// none are a common rejection. Unsure matches (web, medical, wellness)
/// are only worth a look.
struct AgeRatingCheck: ReviewRiskCheck {
    let id = ReviewRiskCheckID.ageRating

    /// What a topic says about one question.
    private struct Rule {
        var topics: [ReviewRiskSignalTopic]
        var question: AgeRatingQuestion
        var level: ReviewRiskLevel
        var howSure: HowSure
    }

    private static let rules: [Rule] = [
        Rule(topics: [.dating], question: .datingAndRelationships, level: .likely, howSure: .fairlySure),
        Rule(topics: [.messaging], question: .messaging, level: .likely, howSure: .fairlySure),
        Rule(topics: [.community, .liveStream], question: .userGeneratedContent, level: .likely, howSure: .fairlySure),
        Rule(topics: [.simulatedGambling], question: .simulatedGambling, level: .likely, howSure: .fairlySure),
        Rule(topics: [.advertising], question: .advertising, level: .likely, howSure: .fairlySure),
        Rule(topics: [.webAccess], question: .webAccess, level: .check, howSure: .fairlySure),
        Rule(topics: [.medical], question: .medical, level: .check, howSure: .notVerySure),
        Rule(topics: [.wellness], question: .wellness, level: .check, howSure: .notVerySure),
    ]

    /// Added to the questionnaire later (API 4.6): App Store Connect may
    /// not ask for them yet everywhere.
    static let newerQuestions: Set<AgeRatingQuestion> = [.socialMediaAgeRestricted, .datingAndRelationships, .sharedLocation]

    /// Categories that make health topics likely.
    static let healthCategories: Set<String> = ["HEALTH_AND_FITNESS", "MEDICAL"]

    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome {
        guard let content = facts.content, let answers = content.ageRating else {
            return .notChecked(String(localized: "Atlas couldn’t read the age rating answers.", comment: "kind:error · an App Review check that couldn’t run"))
        }
        let unanswered = Set(content.unansweredQuestions)
        var found: [AgeRatingQuestion: [ReviewRiskSignal]] = [:]
        var risks: [ReviewRisk] = []
        for rule in Self.rules {
            let signals = Self.signals(for: rule, in: facts, content: content)
            guard !signals.isEmpty, !answers[rule.question].isPresent else { continue }
            if rule.question == .simulatedGambling, answers[.gambling].isPresent { continue }
            found[rule.question] = signals
            guard !unanswered.contains(rule.question) else { continue }
            risks.append(mismatch(rule, answer: answers[rule.question], signals: signals))
        }
        if !content.unansweredQuestions.isEmpty {
            risks.insert(unansweredRisk(content.unansweredQuestions, signals: found), at: 0)
        }
        return .risks(risks)
    }

    private static func signals(for rule: Rule, in facts: ReviewRiskFacts, content: ReviewRiskContentFacts) -> [ReviewRiskSignal] {
        var signals = ReviewRiskSignalScanner.scan(rule.topics, in: facts)
        let categories = [content.primaryCategory, content.secondaryCategory].compactMap(\.self)
        if rule.question == .wellness, let category = categories.first(where: { healthCategories.contains($0) }) {
            signals.append(ReviewRiskSignal(
                topic: .wellness,
                term: AppCategory.name(for: category),
                source: .category,
                evidence: ReviewRiskEvidence(
                    place: String(localized: "Category", comment: "kind:label · where an App Review risk shows: the app's category"),
                    excerpt: AppCategory.name(for: category)
                )
            ))
        }
        return signals
    }

    private func mismatch(_ rule: Rule, answer: AgeRatingAnswer, signals: [ReviewRiskSignal]) -> ReviewRisk {
        let question = rule.question
        let first = signals[0]
        let term = String(first.term.prefix(first.source == .project ? 40 : 24))
        let why = switch first.source {
        case .project:
            String(localized: "The project uses \(term); the age rating says the app has none (2.3.6).", comment: "kind:why · an App Review risk")
        case .category:
            String(
                localized: "The app’s category is \(term); App Review rejects an age rating that doesn’t match (2.3.6).",
                comment: "kind:why · an App Review risk"
            )
        default:
            String(
                localized: "Your texts say “\(term)”; App Review rejects an age rating that doesn’t match (2.3.6).",
                comment: "kind:why · an App Review risk"
            )
        }
        let advice = question.hasLevels
            ? String(
                localized: "If the app has it, answer Infrequent or Frequent; if not, change the words that say it.",
                comment: "kind:detail · how to fix an App Review risk"
            )
            : String(localized: "If the app has it, answer Yes; if not, change the words that say it.", comment: "kind:detail · how to fix an App Review risk")
        return ReviewRisk(
            check: id,
            subject: question.rawValue,
            level: rule.level,
            title: String(
                localized: "\(question.title) answered \(answer.title)",
                comment: "kind:title · an App Review risk: an age rating answer, e.g. “Messaging and chat answered No”"
            ),
            why: why,
            evidence: Self.evidence(signals) + [ReviewRiskEvidence(place: ReviewRiskSignalScanner.ageRatingPlace(question), excerpt: answer.title)],
            howSure: rule.howSure,
            fix: ReviewRiskFix(advice: advice, tool: "propose_age_rating", arguments: ["question": question.rawValue])
        )
    }

    private func unansweredRisk(_ questions: [AgeRatingQuestion], signals: [AgeRatingQuestion: [ReviewRiskSignal]]) -> ReviewRisk {
        let count = questions.count
        let title = count == 1
            ? String(localized: "1 age rating question not answered", comment: "kind:title · an App Review risk")
            : String(localized: "\(count) age rating questions not answered", comment: "kind:title · an App Review risk")
        let why = count == 1
            ? String(localized: "App Store Connect won’t take the version for review until it’s answered.", comment: "kind:why · an App Review risk")
            : String(
                localized: "App Store Connect won’t take the version for review until all \(count) are answered.",
                comment: "kind:why · an App Review risk"
            )
        let pointed = questions.filter { signals[$0] != nil }
        let advice = pointed.isEmpty
            ? String(localized: "Answer them on the Age Rating page.", comment: "kind:detail · how to fix an App Review risk")
            : String(
                localized: "Answer them on the Age Rating page; the app’s words point to Yes for \(pointed.map(\.title).formatted(.list(type: .and))).",
                comment: "kind:detail · how to fix an App Review risk"
            )
        let questionEvidence = questions.prefix(6).map { question in
            ReviewRiskEvidence(
                place: ReviewRiskSignalScanner.ageRatingPlace(question),
                excerpt: String(localized: "Not answered", comment: "kind:label · an age rating question with no answer")
            )
        }
        let signalEvidence = Self.evidence(pointed.flatMap { signals[$0] ?? [] })
        return ReviewRisk(
            check: id,
            subject: "unanswered",
            level: .blocksReview,
            title: title,
            why: why,
            evidence: questionEvidence + signalEvidence,
            howSure: questions.allSatisfy { Self.newerQuestions.contains($0) } ? .fairlySure : .sure,
            fix: ReviewRiskFix(
                advice: advice,
                tool: "propose_age_rating",
                arguments: ["question": questions.map(\.rawValue).joined(separator: ",")]
            )
        )
    }

    private static func evidence(_ signals: [ReviewRiskSignal]) -> [ReviewRiskEvidence] {
        ReviewRiskSignal.evidence(signals)
    }
}
