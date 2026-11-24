//
//  ReviewBulkPlan.swift
//  Atlas
//

import Foundation

/// Reply to All for one group: one message per language, each going under
/// its own reviews. Reviews already replied to are left out, and so are
/// the ones in a language the group has no message for.
struct ReviewBulkPlan: Hashable, Sendable {
    var theme: ReviewTheme
    /// Most reviews first.
    var rows: [ReviewBulkRow]
    /// Unanswered reviews of the group in a language without a message.
    var leftOutCount: Int

    static func make(_ theme: ReviewTheme, reviews: [AppReview]) -> ReviewBulkPlan {
        let ids = Set(theme.reviewIDs)
        let open = reviews.filter { ids.contains($0.id) && !$0.hasReply }
        var rows: [String: ReviewBulkRow] = [:]
        var leftOut = 0
        for review in open {
            guard let reply = theme.reply(forLanguage: review.languageCode) else {
                leftOut += 1
                continue
            }
            let code = ReviewTheme.base(reply.languageCode)
            rows[code, default: ReviewBulkRow(
                languageCode: code, languageName: ReviewLanguage.name(of: code), territory: "", text: reply.text, reviewIDs: [],
                gloss: reply.gloss
            )].reviewIDs.append(review.id)
        }
        let territories = Dictionary(open.map { ($0.id, $0.territory) }) { first, _ in first }
        var sorted = rows.values.map { row -> ReviewBulkRow in
            var row = row
            row.territory = mostCommon(row.reviewIDs.compactMap { territories[$0] })
            return row
        }
        sorted.sort { lhs, rhs in
            lhs.reviewIDs.count == rhs.reviewIDs.count ? lhs.languageCode < rhs.languageCode : lhs.reviewIDs.count > rhs.reviewIDs.count
        }
        return ReviewBulkPlan(theme: theme, rows: sorted, leftOutCount: leftOut)
    }

    /// The storefront most of `territories` are; "" without any.
    private static func mostCommon(_ territories: [String]) -> String {
        var counts: [String: Int] = [:]
        for territory in territories where !territory.isEmpty {
            counts[territory, default: 0] += 1
        }
        let best = counts.max { lhs, rhs in
            lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
        }
        return best?.key ?? ""
    }

    /// Every review that would get a reply.
    var replyCount: Int {
        rows.reduce(0) { $0 + $1.reviewIDs.count }
    }

    /// How many replies the ticked languages send.
    func replyCount(selected: Set<String>) -> Int {
        rows.filter { selected.contains($0.languageCode) }.reduce(0) { $0 + $1.reviewIDs.count }
    }

    /// "Reply to 38 reviews about iCloud sync since 1.3".
    var title: String {
        String(localized: "Reply to \(ReviewText.reviews(replyCount)) about \(theme.title)")
    }
}
