//
//  UserContentCheck.swift
//  Atlas
//

import Foundation

/// 1.2: an app where people post, chat or meet needs a way to filter
/// objectionable content, report it, block abusive users, and published
/// contact details. Apps that create content with AI count too (1.2.1(a),
/// October 2026). App Review asks where those tools are, so the notes
/// should say; and the Support URL is the contact people reach.
struct UserContentCheck: ReviewRiskCheck {
    let id = ReviewRiskCheckID.userContent

    /// Words that show the notes explain reporting, blocking or
    /// moderation, as parts of words ("reporting", "blocked").
    static let moderationWords = [
        "report", "block", "moderat", "flag", "filter", "mute", "abuse", "safety", "objectionable",
        "举报", "屏蔽", "审核", "拉黑", "过滤",
    ]

    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome {
        guard let content = facts.content else {
            return .notChecked(String(localized: "Atlas couldn’t read App Information.", comment: "kind:error · an App Review check that couldn’t run"))
        }
        let answered = [AgeRatingQuestion.messaging, .userGeneratedContent, .socialMedia].compactMap { question in
            ReviewRiskSignalScanner.ageRatingSignal(question == .messaging ? .messaging : .community, question: question, in: content)
        }
        let strong = ReviewRiskSocialSignals(facts).strong.filter { $0.source != .ageRating }
        let aiCreation = ReviewRiskAISignals(facts).creation.filter(\.isText)
        let signals = answered + strong + aiCreation
        guard !signals.isEmpty else { return .clear }
        let isPeople = !answered.isEmpty || !strong.isEmpty
        var risks: [ReviewRisk] = []
        if content.hasReviewInformation, !Self.explainsModeration(content.reviewNotes) {
            risks.append(notesRisk(signals, isPeople: isPeople, notes: content.reviewNotes))
        }
        if Self.lacksSupportURL(facts) {
            risks.append(supportRisk(signals, facts: facts))
        }
        return .risks(risks)
    }

    static func explainsModeration(_ notes: String) -> Bool {
        moderationWords.contains { notes.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    /// No Support URL in any language; false when it couldn't be read.
    static func lacksSupportURL(_ facts: ReviewRiskFacts) -> Bool {
        if let links = facts.links {
            return links.supportURLs.values.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        guard let url = facts.content?.supportURL else { return false }
        return url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func notesRisk(_ signals: [ReviewRiskSignal], isPeople: Bool, notes: String) -> ReviewRisk {
        let notesEvidence = ReviewRiskEvidence(
            place: ReviewRiskSignalScanner.reviewNotesPlace,
            excerpt: notes.isEmpty ? String(localized: "Empty", comment: "kind:label · a text field with nothing in it") : notes
        )
        return ReviewRisk(
            check: id,
            subject: "reviewNotes",
            level: isPeople ? .likely : .check,
            title: String(localized: "Review notes skip reporting and blocking", comment: "kind:title · an App Review risk"),
            why: String(
                localized: "Guideline 1.2 asks for report, block and filter tools; your App Review notes don’t say where they are.",
                comment: "kind:why · an App Review risk"
            ),
            evidence: ReviewRiskSignal.evidence(signals) + [notesEvidence],
            howSure: isPeople ? .fairlySure : .notVerySure,
            fix: ReviewRiskFix(
                advice: String(
                    localized: "Add a short note on how people report content and block users, and how you filter what they post.",
                    comment: "kind:detail · how to fix an App Review risk"
                ),
                tool: "suggest_fields",
                arguments: ["area": "info", "page": "review", "field": "notes"]
            )
        )
    }

    private func supportRisk(_ signals: [ReviewRiskSignal], facts: ReviewRiskFacts) -> ReviewRisk {
        let locale = facts.links?.primaryLocale ?? facts.texts?.primaryLocale
            ?? facts.content?.texts.first(where: { $0.place == .storeListing })?.locale
        var arguments = ["area": "store", "field": ListingField.supportURL.rawValue]
        if let locale { arguments["locale"] = locale }
        return ReviewRisk(
            check: id,
            subject: "supportURL",
            level: .likely,
            title: String(localized: "No Support URL for people to reach you", comment: "kind:title · an App Review risk"),
            why: String(
                localized: "Apps with user content must publish a way to contact you (1.2); the Support URL is empty.",
                comment: "kind:why · an App Review risk"
            ),
            evidence: ReviewRiskSignal.evidence(signals, limit: 2)
                + [ReviewRiskEvidence(place: ListingField.supportURL.title, excerpt: String(
                    localized: "Empty",
                    comment: "kind:label · a text field with nothing in it"
                ))],
            howSure: .sure,
            fix: ReviewRiskFix(
                advice: String(
                    localized: "Add a Support URL with a way to reach you in every language.",
                    comment: "kind:detail · how to fix an App Review risk"
                ),
                tool: "suggest_fields",
                arguments: arguments
            )
        )
    }
}
