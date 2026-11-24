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
        return .object(object)
    }

    static func theme(_ theme: ReviewTheme) -> JSONValue {
        var entry: [String: JSONValue] = [
            "id": .string(theme.id),
            "title": .string(theme.title),
            "note": .string(theme.note),
            "reviews": .int(theme.reviewIDs.count),
            "action": .string(theme.action.code),
            "languages": .array(theme.replies.map { .string($0.languageCode) }),
        ]
        theme.layers?.add(to: &entry)
        return .object(entry)
    }
}
