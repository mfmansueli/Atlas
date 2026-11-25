//
//  ReviewRiskSignalScanner.swift
//  Atlas
//

import Foundation

/// Looks for topics in what App Review reads: the store texts (every
/// language when `ReviewRiskFacts.texts` was read, else the primary
/// language and Simplified Chinese), App Review's notes, and the
/// project's packages and imports. One signal per topic per text, package
/// or module, so a long description doesn't flood the evidence.
enum ReviewRiskSignalScanner {
    /// The listing fields that say what the app does.
    static let fields: Set<ListingField> = [.name, .subtitle, .description, .keywords, .promotionalText]

    static func scan(_ topics: [ReviewRiskSignalTopic], in facts: ReviewRiskFacts) -> [ReviewRiskSignal] {
        let readable = Self.texts(in: facts)
        return topics.flatMap { topic in
            readable.compactMap { signal(topic, in: $0) } + projectSignals(topic, in: facts.project)
        }
    }

    /// What the content checks read: the shared store texts when there are
    /// any, else the content facts' own copy, and the review notes either way.
    static func texts(in facts: ReviewRiskFacts) -> [ReviewRiskText] {
        let own = facts.content?.texts ?? []
        let shared = (facts.texts?.texts ?? []).filter { text in
            switch text.place {
            case .storeListing: text.field.map { fields.contains($0) } ?? false
            case .reviewNotes: true
            default: false
            }
        }
        guard !shared.isEmpty else { return own.filter { !$0.text.isEmpty } }
        let hasNotes = shared.contains { $0.place == .reviewNotes }
        let ownNotes = hasNotes ? [] : own.filter { $0.place == .reviewNotes }
        return (shared + ownNotes).filter { !$0.text.isEmpty }
    }

    /// The topic's first word in `text`.
    static func signal(_ topic: ReviewRiskSignalTopic, in text: ReviewRiskText) -> ReviewRiskSignal? {
        let isNotes = text.place == .reviewNotes
        let words = topic.words + (isNotes ? topic.reviewNotesWords : [])
        for word in words {
            guard let range = ReviewRiskTermMatcher.range(of: word, in: text.text, excluding: topic.exclusions) else { continue }
            return ReviewRiskSignal(
                topic: topic,
                term: String(text.text[range]),
                source: isNotes ? .reviewNotes : .storeText,
                evidence: ReviewRiskEvidence(
                    place: text.label,
                    excerpt: ReviewRiskTermMatcher.excerpt(around: range, in: text.text),
                    locale: text.locale.isEmpty ? nil : text.locale
                )
            )
        }
        return nil
    }

    /// The topic's packages and modules in the project.
    static func projectSignals(_ topic: ReviewRiskSignalTopic, in project: ReviewRiskProjectFacts?) -> [ReviewRiskSignal] {
        guard let project else { return [] }
        let place = String(localized: "Project · \(project.folderName)", comment: "kind:label · where an App Review risk shows: the app's Xcode project")
        let packages = project.packages.sorted().filter { name in
            let lowered = name.lowercased()
            return topic.packages.contains { lowered.contains($0) }
        }
        let imports = project.imports.sorted().filter { topic.imports.contains($0) }
        return (packages + imports).map { name in
            ReviewRiskSignal(topic: topic, term: name, source: .project, evidence: ReviewRiskEvidence(place: place, excerpt: name))
        }
    }

    /// The question's answer as a sign: "Age Rating · Messaging and chat: Yes".
    static func ageRatingSignal(_ topic: ReviewRiskSignalTopic, question: AgeRatingQuestion, in content: ReviewRiskContentFacts?) -> ReviewRiskSignal? {
        guard let content, content.answers(question), let answers = content.ageRating else { return nil }
        return ReviewRiskSignal(
            topic: topic,
            term: question.title,
            source: .ageRating,
            evidence: ReviewRiskEvidence(place: ageRatingPlace(question), excerpt: answers[question].title)
        )
    }

    /// The review notes as the place of evidence.
    static var reviewNotesPlace: String {
        String(localized: "App Review notes", comment: "kind:label · where an App Review risk shows: the version's notes for App Review")
    }

    /// "Age Rating · Messaging and chat".
    static func ageRatingPlace(_ question: AgeRatingQuestion) -> String {
        String(localized: "Age Rating · \(question.title)", comment: "kind:label · where an App Review risk shows: one age rating question")
    }
}
