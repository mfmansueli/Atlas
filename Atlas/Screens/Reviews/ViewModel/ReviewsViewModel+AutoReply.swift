//
//  ReviewsViewModel+AutoReply.swift
//  Atlas
//

import Foundation

// Reply Automatically in Reviews (board 58): the rule, the strip, each
// reply's state under its review, and History with Undo.
extension ReviewsViewModel {
    var autoReplyRule: AutoReplyRule { autoReply.rule(for: app.id) }

    /// The strip shows while it's on, on Pro.
    var showsAutoReplyStrip: Bool { autoReplyRule.isOn && isPro }

    /// Reply Automatically's record of the review's suggested reply.
    func autoReplyDraft(for review: AppReview) -> AutoReplyDraft? {
        guard isPro, let draft = autoReply.draft(for: review.id, appID: app.id), !AutoReplyCenter.isSent(draft) else { return nil }
        return draft
    }

    /// Don't Send: it stays under the review, with Send.
    func dontSend(_ review: AppReview) {
        autoReply.hold(review.id, appID: app.id)
        keptVisible.insert(review.id)
    }

    func saveAutoReply(_ rule: AutoReplyRule) {
        let wasOn = autoReplyRule.isOn
        autoReply.setRule(rule, for: app.id)
        toast = ToastMessage(text: wasOn
            ? String(localized: "Saved. Changes apply to the next review.")
            : String(localized: "Reply Automatically is on. New reviews get a reply from the next check."))
    }

    func turnOffAutoReply() {
        var rule = autoReplyRule
        rule.isOn = false
        autoReply.setRule(rule, for: app.id)
        toast = ToastMessage(text: String(localized: "Reply Automatically is off. Replies already written stay under their reviews."))
    }

    func setAutoReplyPaused(_ paused: Bool) {
        autoReply.setPaused(paused, for: app.id)
    }

    /// Why due replies wait, for the strip.
    var autoReplyHold: String? { autoReply.sendingHold(for: app.id, reviews: store) }

    var autoReplyWriteProblem: String? { autoReply.archive(for: app.id).writeProblem }

    var autoReplyHistory: [AutoReplyHistoryEntry] { autoReply.archive(for: app.id).history }

    /// The languages the app's reviews are in, for the settings.
    var reviewLanguages: [String] {
        Set(archive.reviews.map { ReviewTheme.base($0.languageCode) }.filter { !$0.isEmpty }).sorted {
            ReviewLanguage.name(of: $0) < ReviewLanguage.name(of: $1)
        }
    }

    /// Undo in History; nil when it worked, else why not.
    func undoAutoReply(_ entry: AutoReplyHistoryEntry) async -> String? {
        do {
            try await autoReply.undo(entry, app: app, reviews: store, services: services)
            keptVisible.insert(entry.reviewID)
            return nil
        } catch {
            return String(localized: "The reply couldn’t be taken back: \(error.localizedDescription)")
        }
    }
}
