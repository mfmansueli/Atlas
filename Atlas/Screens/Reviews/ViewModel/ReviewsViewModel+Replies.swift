//
//  ReviewsViewModel+Replies.swift
//  Atlas
//

import Foundation

// Writing and sending replies. A reply is public the moment Apple
// publishes it, so nothing is sent without Send Reply; Undo takes it back
// (or puts back the reply it replaced).
extension ReviewsViewModel {
    /// The text the editor starts with: the draft, else the suggestion,
    /// else the reply that's there.
    func draft(for review: AppReview) -> String {
        drafts[review.id] ?? archive.openSuggestion(for: review)?.text ?? review.reply?.text ?? ""
    }

    /// "Edit…" on a suggestion, "Write a Reply…", or "Edit" on a reply.
    func startEditing(_ review: AppReview) {
        // An automatic reply being edited is the person's: it won't go
        // out by itself.
        if autoReply.draft(for: review.id, appID: app.id)?.state.isScheduled == true { autoReply.hold(review.id, appID: app.id) }
        let text = isPro ? draft(for: review) : drafts[review.id] ?? review.reply?.text ?? ""
        drafts[review.id] = text
        replyErrors[review.id] = nil
        editingID = review.id
    }

    func cancelEditing() {
        if let editingID { drafts[editingID] = nil }
        editingID = nil
    }

    /// What the suggested reply means, under the editor, while the draft
    /// is still the suggestion's.
    func draftMeaning(for review: AppReview) -> String? {
        guard isPro, let suggestion = archive.suggestions[review.id], !suggestion.meaning.isEmpty else { return nil }
        return suggestion.meaning
    }

    func canSend(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= ReviewText.replyLimit
    }

    /// Send Reply on a suggestion, as suggested.
    func sendSuggestion(for review: AppReview) async {
        guard let suggestion = archive.openSuggestion(for: review) else { return }
        await send(suggestion.text, to: review)
    }

    /// Send Reply in the editor.
    func sendDraft(for review: AppReview) async {
        await send(draft(for: review), to: review)
    }

    /// Sends `text` under `review`; the toast offers Undo.
    func send(_ text: String, to review: AppReview) async {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend(text), !sending.contains(review.id) else { return }
        sending.insert(review.id)
        defer { sending.remove(review.id) }
        do {
            let reply = try await services.sendReply(text, to: review.id)
            didSend(reply, to: review)
            undo = ReviewReplyUndo(reviewID: review.id, sent: reply, previous: review.reply)
            toast = ToastMessage(text: Self.sentText(territory: review.territoryName), canUndo: true)
        } catch {
            replyErrors[review.id] = AppleErrorCopy(String(localized: "The reply wasn’t sent.", comment: "kind:error"), error: error).text
        }
    }

    private func didSend(_ reply: ReviewReply, to review: AppReview) {
        store.setReply(reply, reviewID: review.id, for: app.id)
        // The write works: Reply Automatically may send by itself now.
        store.markReplySentByHand()
        autoReply.personReplied(to: review.id, appID: app.id)
        keptVisible.insert(review.id)
        sentNow.insert(review.id)
        replyErrors[review.id] = nil
        drafts[review.id] = nil
        if editingID == review.id { editingID = nil }
    }

    /// "Reply sent to Germany. It shows on the App Store, usually within
    /// a day."
    static func sentText(territory: String) -> String {
        territory.isEmpty
            ? String(localized: "Reply sent. It shows on the App Store, usually within a day.")
            : String(localized: "Reply sent to \(territory). It shows on the App Store, usually within a day.")
    }

    /// Undo on the toast: the reply comes off the App Store, or the one it
    /// replaced goes back.
    func undoReply() async {
        guard let undo else { return }
        self.undo = nil
        toast = nil
        do {
            if let previous = undo.previous {
                let restored = try await services.sendReply(previous.text, to: undo.reviewID)
                store.setReply(restored, reviewID: undo.reviewID, for: app.id)
            } else {
                try await services.deleteReply(undo.sent.id)
                store.setReply(nil, reviewID: undo.reviewID, for: app.id)
            }
            sentNow.remove(undo.reviewID)
        } catch {
            replyErrors[undo.reviewID] = AppleErrorCopy(String(localized: "The reply couldn’t be taken back.", comment: "kind:error"), error: error).text
        }
    }

    /// Dismiss on a suggestion. The review still has no reply.
    func dismissSuggestion(for review: AppReview) {
        store.dismissSuggestion(reviewID: review.id, for: app.id)
        autoReply.personReplied(to: review.id, appID: app.id)
        keptVisible.insert(review.id)
    }

    func restoreSuggestion(for review: AppReview) {
        store.restoreSuggestion(reviewID: review.id, for: app.id)
    }

    /// "You replied Nov 16. Apple shows it under the review, usually
    /// within a day."
    func sentText(for reply: ReviewReply) -> String {
        String(localized: "You replied \(ReviewText.day(reply.date)). Apple shows it under the review, usually within a day.")
    }

    /// "Your reply · Nov 10 · On the App Store".
    func repliedText(for reply: ReviewReply) -> String {
        let place = reply.isPending ? String(localized: "Waiting for Apple to publish it") : String(localized: "On the App Store")
        return String(localized: "Your reply · \(ReviewText.day(reply.date)) · \(place)")
    }
}
