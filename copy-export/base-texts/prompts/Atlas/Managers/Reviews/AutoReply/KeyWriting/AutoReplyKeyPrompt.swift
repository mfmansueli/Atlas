//
//  AutoReplyKeyPrompt.swift
//  Atlas
//

import Foundation

/// Reply Automatically through the person's own API key, when Claude Code
/// can't start (board 58): one request with the new reviews, asking for a
/// reply to each in its language and what it's about, as JSON.
enum AutoReplyKeyPrompt {
    static func system(app: String, rule: AutoReplyRule) -> String {
        let topics = AutoReplyTopic.allCases.map(\.key).joined(separator: ", ")
        let signature = rule.signature.trimmingCharacters(in: .whitespacesAndNewlines)
        let sign = signature.isEmpty ? "" : " End each reply with “— \(signature)” on its own line."
        return """
        You reply to App Store reviews of \(app) for its developer. For each review, write a reply in the reviewer’s own \
        language, \(rule.tone.instruction), specific to what they wrote, a few sentences at most.\(sign) \
        \(StoreTextGuidelinePlace.reviewReply.summary) Never mention prices, offers, other apps or dates for new features, \
        never promise what you can’t know is there, and never ask for a better rating. \
        Answer with JSON only: {"replies": [{"reviewId": "…", "text": "the reply", "meaning": "what it says, in English", \
        "waitTopics": [], "unsure": false}]}, one per review. waitTopics are the ones the review is about, from: \(topics). \
        unsure is true when you aren’t sure what the reviewer means.
        """
    }

    /// The reviews as JSON lines: id, stars, language, title and text.
    static func user(_ reviews: [AppReview]) -> String {
        let lines = reviews.map { review -> String in
            let fields: [String: String] = [
                "reviewId": review.id, "stars": String(review.rating), "language": review.languageCode,
                "country": review.territory, "title": review.title, "text": review.body,
            ]
            let data = (try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])) ?? Data()
            return String(bytes: data, encoding: .utf8) ?? ""
        }
        return "Reviews:\n" + lines.joined(separator: "\n")
    }
}
