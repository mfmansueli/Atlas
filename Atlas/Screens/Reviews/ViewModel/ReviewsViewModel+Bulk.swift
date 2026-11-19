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

    /// Replies sent at once: each is its own review, so none waits for
    /// another.
    static let concurrentReplies = 6

    /// Sends the ticked languages' messages, several reviews at a time. The
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
        var pending = rows.flatMap { row in
            row.reviewIDs.filter { archive.review(id: $0)?.hasReply == false }.map { (text: row.text, reviewID: $0, language: row.languageCode) }
        }[...]
        await withTaskGroup(of: (reviewID: AppReview.ID, language: String, result: Result<ReviewReply, any Error>).self) { group in
            for reply in pending.prefix(Self.concurrentReplies) {
                group.addTask { await self.sendBulkReply(reply.text, to: reply.reviewID, language: reply.language) }
            }
            pending = pending.dropFirst(Self.concurrentReplies)
            while let done = await group.next() {
                switch done.result {
                case let .success(reply):
                    store.setReply(reply, reviewID: done.reviewID, for: app.id)
                    keptVisible.insert(done.reviewID)
                    sentNow.insert(done.reviewID)
                    sent += 1
                    languages.insert(done.language)
                case let .failure(error):
                    failure = error.localizedDescription
                }
                bulkProgress = ReviewBulkProgress(sent: sent, total: total)
                if let reply = pending.popFirst() {
                    group.addTask { await self.sendBulkReply(reply.text, to: reply.reviewID, language: reply.language) }
                }
            }
        }
        bulkProgress = nil
        finishBulk(plan, sent: sent, languageCount: languages.count, failure: failure)
    }

    /// One reply of a bulk send, with what it was for.
    private func sendBulkReply(
        _ text: String, to reviewID: AppReview.ID, language: String
    ) async -> (reviewID: AppReview.ID, language: String, result: Result<ReviewReply, any Error>) {
        do {
            return try await (reviewID, language, .success(services.sendReply(text, to: reviewID)))
        } catch {
            return (reviewID, language, .failure(error))
        }
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
