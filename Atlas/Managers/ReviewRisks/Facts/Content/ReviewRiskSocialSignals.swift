//
//  ReviewRiskSocialSignals.swift
//  Atlas
//

import Foundation

/// Signs that people reach each other in an app: dating, messaging, a
/// community, live streams, sharing and end-to-end encrypted messages,
/// from the store texts, the review notes, chat and video packages in the
/// project, and age rating answers (Messaging and chat, User-generated
/// content, Social media).
struct ReviewRiskSocialSignals: Hashable, Sendable {
    var signals: [ReviewRiskSignal]

    init(signals: [ReviewRiskSignal]) {
        self.signals = signals
    }

    init(_ facts: ReviewRiskFacts) {
        let found = ReviewRiskSignalScanner.scan([.dating, .messaging, .community, .liveStream, .sharing, .encryptedMessaging], in: facts)
        let answers: [(ReviewRiskSignalTopic, AgeRatingQuestion)] = [
            (.messaging, .messaging), (.community, .userGeneratedContent), (.community, .socialMedia), (.dating, .datingAndRelationships),
        ]
        let answered = answers.compactMap { ReviewRiskSignalScanner.ageRatingSignal($0.0, question: $0.1, in: facts.content) }
        var category: [ReviewRiskSignal] = []
        if facts.content?.primaryCategory == Self.socialNetworking {
            category.append(ReviewRiskSignal(
                topic: .community,
                term: AppCategory.name(for: Self.socialNetworking),
                source: .category,
                evidence: ReviewRiskEvidence(
                    place: String(localized: "Primary category", comment: "kind:label · where an App Review risk shows"),
                    excerpt: AppCategory.name(for: Self.socialNetworking)
                )
            ))
        }
        signals = found + answered + category
    }

    static let socialNetworking = "SOCIAL_NETWORKING"

    var isEmpty: Bool { signals.isEmpty }

    /// People meet, message, post or stream to each other: more than
    /// sharing a file.
    var strong: [ReviewRiskSignal] {
        signals.filter { Self.strongTopics.contains($0.topic) }
    }

    static let strongTopics: Set<ReviewRiskSignalTopic> = [.dating, .messaging, .community, .liveStream]

    /// Something made in the app goes to other people (sharing, or any of
    /// the strong signs).
    var sharing: [ReviewRiskSignal] {
        signals.filter { $0.topic != .encryptedMessaging }
    }

    var encryptedMessaging: [ReviewRiskSignal] { signals.filter { $0.topic == .encryptedMessaging } }

    func of(_ topic: ReviewRiskSignalTopic) -> [ReviewRiskSignal] { signals.filter { $0.topic == topic } }
}
