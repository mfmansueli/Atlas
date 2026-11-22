//
//  AutoReplyCenter+Sending.swift
//  Atlas
//

import Foundation

// Replies going out by themselves, and Undo. Each goes out through the
// same write as Send Reply, public under the review.
extension AutoReplyCenter {
    /// Why allowed replies keep waiting though they're due, for the strip;
    /// nil when they go.
    func sendingHold(for appID: StoreApp.ID, reviews: ReviewsStore) -> String? {
        let rule = rule(for: appID)
        guard rule.isOn, rule.mode == .sendAllowed else { return nil }
        if !isPro() { return String(localized: "Replies go out by themselves with Pro.") }
        if rule.isPaused { return String(localized: "Paused: new replies are drafted and wait for you.") }
        if reviews.settings.sentReplyByHandAt == nil {
            return String(localized: "Nothing goes out by itself until a reply you send yourself has reached the App Store.")
        }
        if sentToday(for: appID) >= rule.dailyCap {
            return String(localized: "\(rule.dailyCap) sent today, the most a day: the rest go tomorrow.")
        }
        return nil
    }

    /// Every reply whose wait is over goes out, oldest wait first, up to
    /// the day's cap. Called on every background tick and check.
    func sendDue(app: StoreApp, reviews: ReviewsStore, services: any ReviewsServices) async {
        guard isActive(for: app.id), sendingHold(for: app.id, reviews: reviews) == nil else { return }
        let date = now()
        let due = archive(for: app.id).drafts.values
            .compactMap { draft in draft.state.sendAt.map { (draft.reviewID, $0) } }
            .filter { $0.1 <= date }
            .sorted { $0.1 < $1.1 }
        for (reviewID, _) in due {
            guard sentToday(for: app.id) < rule(for: app.id).dailyCap else { return }
            await send(reviewID, app: app, reviews: reviews, services: services)
        }
    }

    /// One reply going out by itself. A review that got a reply meanwhile
    /// keeps that one; a reply that's gone or too old waits for the
    /// person; one Apple refuses says why and waits.
    func send(_ reviewID: AppReview.ID, app: StoreApp, reviews: ReviewsStore, services: any ReviewsServices) async {
        guard !sendingIDs.contains(reviewID), let draft = draft(for: reviewID, appID: app.id), draft.state.isScheduled else { return }
        let archive = reviews.archive(for: app.id)
        guard let review = archive.review(id: reviewID), !review.hasReply else {
            update(app.id) { $0.drafts[reviewID] = nil }
            return
        }
        guard let suggestion = archive.openSuggestion(for: review) else {
            update(app.id) { $0.drafts[reviewID]?.state = .held }
            return
        }
        let date = now()
        guard date.timeIntervalSince(review.date) <= AutoReplyRule.maximumAge else {
            update(app.id) { $0.drafts[reviewID]?.state = .needsYou(reason: String(localized: "it’s more than a week old")) }
            return
        }
        sendingIDs.insert(reviewID)
        defer { sendingIDs.remove(reviewID) }
        do {
            let reply = try await services.sendReply(suggestion.text, to: reviewID)
            reviews.setReply(reply, reviewID: reviewID, for: app.id)
            let rule = rule(for: app.id)
            update(app.id) { archive in
                archive.drafts[reviewID]?.state = .sent(replyID: reply.id, sentAt: date)
                archive.history.insert(AutoReplyHistoryEntry(
                    reviewID: reviewID, replyID: reply.id, text: suggestion.text, rating: review.rating,
                    reviewer: [review.nickname, review.territoryName].filter { !$0.isEmpty }.joined(separator: ", "),
                    sentAt: date, rule: rule.summary
                ), at: 0)
            }
        } catch {
            update(app.id) { $0.drafts[reviewID]?.state = .needsYou(reason: String(localized: "it couldn’t be sent: \(error.localizedDescription)")) }
        }
    }

    /// Undo in History: the reply comes off the App Store and the draft
    /// stays under the review, with Send. Throws Apple's refusal.
    func undo(_ entry: AutoReplyHistoryEntry, app: StoreApp, reviews: ReviewsStore, services: any ReviewsServices) async throws {
        guard entry.undoneAt == nil else { return }
        try await services.deleteReply(entry.replyID)
        reviews.setReply(nil, reviewID: entry.reviewID, for: app.id)
        reviews.restoreSuggestion(reviewID: entry.reviewID, for: app.id)
        let date = now()
        update(app.id) { archive in
            if let index = archive.history.firstIndex(where: { $0.id == entry.id }) { archive.history[index].undoneAt = date }
            archive.drafts[entry.reviewID]?.state = .held
        }
    }
}
