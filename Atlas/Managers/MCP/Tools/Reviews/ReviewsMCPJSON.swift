//
//  ReviewsMCPJSON.swift
//  Atlas
//

import Foundation

/// How the reviews tools write a review and a group for an assistant.
enum ReviewsMCPJSON {
    static func review(_ review: AppReview, in archive: ReviewsArchive) -> JSONValue {
        var object: [String: JSONValue] = [
            "id": .string(review.id),
            "territory": .string(review.territory),
            "rating": .int(review.rating),
            "title": .string(review.title),
            "body": .string(review.body),
            "date": .string(review.date.formatted(.iso8601)),
            "needsReply": .bool(review.needsReply),
        ]
        if !review.languageCode.isEmpty { object["language"] = .string(review.languageCode) }
        if let version = review.version { object["version"] = .string(version) }
        if let reply = review.reply {
            object["reply"] = ["text": .string(reply.text), "date": .string(reply.date.formatted(.iso8601))]
        }
        if let suggestion = archive.openSuggestion(for: review) {
            object["suggestedReply"] = ["text": .string(suggestion.text), "by": .string(suggestion.source)]
        }
        if let replacement = archive.openReplacement(for: review) {
            object["suggestedReplacement"] = [
                "text": .string(replacement.text), "by": .string(replacement.source), "why": .string(replacement.why ?? ""),
            ]
        }
        if archive.dismissed.contains(review.id), let dismissed = archive.suggestions[review.id] {
            object["suggestionDismissed"] = ["text": .string(dismissed.text), "by": .string(dismissed.source)]
        }
        return .object(object)
    }

    static func theme(_ theme: ReviewTheme) -> JSONValue {
        self.theme(theme, includesReviewIDs: false)
    }

    /// A group; with its review ids when the assistant asked for the group.
    static func theme(_ theme: ReviewTheme, includesReviewIDs: Bool) -> JSONValue {
        var entry: [String: JSONValue] = [
            "id": .string(theme.id),
            "title": .string(theme.title),
            "note": .string(theme.note),
            "reviews": .int(theme.reviewIDs.count),
            "action": .string(theme.action.code),
            "languages": .array(theme.replies.map { .string($0.languageCode) }),
        ]
        if includesReviewIDs { entry["reviewIds"] = .array(theme.reviewIDs.map(JSONValue.string)) }
        theme.layers?.add(to: &entry)
        return .object(entry)
    }
}
