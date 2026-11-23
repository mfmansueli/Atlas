//
//  AutoReplyCenter+Writing.swift
//  Atlas
//

import Foundation

// Asking the person's Claude Code to write the replies, on each check.
extension AutoReplyCenter {
    /// Asked again after this long when nothing came back.
    static let requestTimeout: TimeInterval = 2 * 60 * 60

    /// The new reviews a reply should be written for: written since the
    /// rule was turned on, within the week, without a reply, a suggestion,
    /// a record here, or a request still being worked on.
    func reviewsToWrite(for appID: StoreApp.ID, reviews: ReviewsArchive) -> [AppReview] {
        let archive = archive(for: appID)
        guard archive.rule.isOn, let since = archive.rule.onSince else { return [] }
        let date = now()
        return reviews.reviews.filter { review in
            let isNew = !review.hasReply && review.date >= since && date.timeIntervalSince(review.date) <= AutoReplyRule.maximumAge
            guard isNew, archive.drafts[review.id] == nil, reviews.suggestions[review.id] == nil else { return false }
            if let asked = archive.requested[review.id], date.timeIntervalSince(asked) < Self.requestTimeout { return false }
            return true
        }
    }

    /// On a check: starts Claude Code on the app's new reviews, in a
    /// project folder Atlas already knows (never asking for one with
    /// nobody looking); else the person's API key writes them, when it may
    /// read reviews. Without either, the reviews wait and the strip says
    /// why.
    func writeReplies(app: StoreApp, reviews store: ReviewsStore, launcher: ClaudeCodeLauncher, keyAssistant: KeyAssistantController?) async {
        guard isPro() else { return }
        let toWrite = reviewsToWrite(for: app.id, reviews: store.archive(for: app.id))
        guard !toWrite.isEmpty else { return }
        if launcher.canStart, launcher.projectFolder(for: app.id) != nil {
            await startClaudeCode(app: app, reviews: toWrite, launcher: launcher)
        } else if let keyAssistant, keyAssistant.isReady, Self.keyProblem(keyAssistant) == nil {
            await writeWithKey(app: app, reviews: toWrite, store: store, keyAssistant: keyAssistant)
        } else {
            update(app.id) { $0.writeProblem = Self.writeProblem(app: app, launcher: launcher, keyAssistant: keyAssistant) }
        }
    }

    /// Why nothing could write: Claude Code, then the key.
    static func writeProblem(app: StoreApp, launcher: ClaudeCodeLauncher, keyAssistant: KeyAssistantController?) -> String {
        if let keyProblem = keyProblem(keyAssistant) { return String(localized: "Couldn’t write a reply. \(keyProblem)") }
        guard launcher.canStart else {
            return String(localized: "Couldn’t write a reply. Connect Claude Code, or add an API key in Settings → AI Assistants.")
        }
        return String(localized: "Couldn’t write a reply: no project folder for \(app.name). Choose it once with Draft Replies…")
    }

    private func startClaudeCode(app: StoreApp, reviews toWrite: [AppReview], launcher: ClaudeCodeLauncher) async {
        let ids = toWrite.map(\.id)
        let prompt = AutoReplyPrompt.text(app: app.name, reviewIDs: ids, rule: rule(for: app.id))
        guard await launcher.start(.autoReply, appID: app.id, appName: app.name, prompt: prompt) != nil else {
            update(app.id) { $0.writeProblem = String(localized: "Couldn’t write a reply: Claude Code didn’t start.") }
            return
        }
        let date = now()
        update(app.id) { archive in
            for id in ids {
                archive.requested[id] = date
            }
            archive.writeProblem = nil
        }
    }
}
