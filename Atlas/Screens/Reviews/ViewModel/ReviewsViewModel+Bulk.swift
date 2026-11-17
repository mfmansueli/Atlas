//
//  ReviewsViewModel+Bulk.swift
//  Atlas
//

import Foundation

// Reply to All: one message per language, each sent under its own review.
extension ReviewsViewModel {
    /// Opens the sheet for a group, every language ticked.
    func openBulk(_ theme: ReviewTheme) {
        let plan = ReviewBulkPlan.make(theme, reviews: reviews)
        bulkSelection = Set(plan.rows.map(\.languageCode))
        bulkProgress = nil
        bulkPlan = plan
    }

    func toggleBulk(_ row: ReviewBulkRow) {
        if bulkSelection.contains(row.languageCode) {
            bulkSelection.remove(row.languageCode)
        } else {
            bulkSelection.insert(row.languageCode)
        }
    }

    var bulkReplyCount: Int {
        bulkPlan?.replyCount(selected: bulkSelection) ?? 0
    }

    /// "Send 38 Replies".
    var bulkSendTitle: String {
        bulkReplyCount == 1 ? String(localized: "Send 1 Reply") : String(localized: "Send \(bulkReplyCount) Replies")
    }

    var isSendingBulk: Bool { bulkProgress != nil }

    /// Sends the ticked languages' messages, one review at a time. The
    /// sheet closes when every reply went; what Apple refused stays to try
    /// again, with the reason.
    func sendBulk() async {
        guard let plan = bulkPlan, !isSendingBulk else { return }
        let rows = plan.rows.filter { bulkSelection.contains($0.languageCode) }
        let total = rows.reduce(0) { $0 + $1.reviewIDs.count }
        guard total > 0 else { return }
        bulkProgress = ReviewBulkProgress(sent: 0, total: total)
        var sent = 0
        var languages: Set<String> = []
        var failure: String?
        for row in rows {
            for reviewID in row.reviewIDs {
                guard let review = archive.review(id: reviewID), !review.hasReply else { continue }
                do {
                    let reply = try await services.sendReply(row.text, to: reviewID)
                    store.setReply(reply, reviewID: reviewID, for: app.id)
                    keptVisible.insert(reviewID)
                    sentNow.insert(reviewID)
                    sent += 1
                    languages.insert(row.languageCode)
                } catch {
                    failure = error.localizedDescription
                }
                bulkProgress = ReviewBulkProgress(sent: sent, total: total)
            }
        }
        bulkProgress = nil
        finishBulk(plan, sent: sent, languageCount: languages.count, failure: failure)
    }

    private func finishBulk(_ plan: ReviewBulkPlan, sent: Int, languageCount: Int, failure: String?) {
        if let failure {
            // What didn't go stays in the sheet.
            let remaining = ReviewBulkPlan.make(plan.theme, reviews: reviews)
            bulkPlan = remaining.rows.isEmpty ? nil : remaining
            bulkSelection.formIntersection(Set(remaining.rows.map(\.languageCode)))
            errorMessage = sent == 0
                ? String(localized: "The replies couldn’t be sent: \(failure)")
                : String(localized: "\(ReviewText.replies(sent)) sent; the rest couldn’t be: \(failure)")
        } else {
            bulkPlan = nil
        }
        guard sent > 0 else { return }
        undo = nil
        toast = ToastMessage(text: Self.bulkSentText(sent: sent, languageCount: languageCount))
    }

    /// "38 replies sent in 7 languages. Apple shows them under the
    /// reviews, usually within a day."
    static func bulkSentText(sent: Int, languageCount: Int) -> String {
        String(
            localized: "\(ReviewText.replies(sent)) sent in \(ReviewText.languages(languageCount)). Apple shows them under the reviews, usually within a day."
        )
    }
}
