//
//  AutoReplyCenter+KeyWriting.swift
//  Atlas
//

import Foundation

// Writing the replies with the person's own API key, when Claude Code
// can't start. Only with "reviews" allowed in Settings → AI Assistants:
// the reviews go to the key's vendor.
extension AutoReplyCenter {
    /// Why the key can't write, or nil when it can.
    static func keyProblem(_ keyAssistant: KeyAssistantController?) -> String? {
        guard let configuration = keyAssistant?.configuration else { return nil }
        guard configuration.readsReviews else {
            return String(localized: "Your API key can write them once Settings → AI Assistants lets it read reviews.")
        }
        return nil
    }

    /// One request with the reviews; the replies that pass the rules for
    /// replies are kept under their reviews and decided like any others.
    func writeWithKey(app: StoreApp, reviews toWrite: [AppReview], store: ReviewsStore, keyAssistant: KeyAssistantController) async {
        let rule = rule(for: app.id)
        let date = now()
        update(app.id) { archive in
            for review in toWrite {
                archive.requested[review.id] = date
            }
        }
        do {
            let answer = try await keyAssistant.complete(
                system: AutoReplyKeyPrompt.system(app: app.name, rule: rule), user: AutoReplyKeyPrompt.user(toWrite),
                title: String(localized: "Replies to \(toWrite.count) reviews")
            )
            let source = keyAssistant.clientName ?? String(localized: "API key")
            let parsed = try AutoReplyKeyAnswer.parse(answer.text, vendor: keyAssistant.configuration?.vendor ?? .anthropic)
            let ids = Set(toWrite.map(\.id))
            var kept: [ReviewReplySuggestion] = []
            var flags: [AppReview.ID: (topics: Set<AutoReplyTopic>, isUnsure: Bool)] = [:]
            for reply in parsed where ids.contains(reply.reviewId) {
                let text = reply.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, text.count <= ReviewText.replyLimit else { continue }
                kept.append(ReviewReplySuggestion(
                    reviewID: reply.reviewId, text: text, meaning: reply.meaning ?? "", source: source, date: store.now()
                ))
                flags[reply.reviewId] = (reply.topics, reply.unsure ?? false)
            }
            let added = store.add(kept, for: app.id)
            received(added, flags: flags, reviews: store.archive(for: app.id), app: app)
            update(app.id) { $0.writeProblem = kept.isEmpty ? String(localized: "Couldn’t write a reply: the answer had none.") : nil }
        } catch {
            update(app.id) { $0.writeProblem = String(localized: "Couldn’t write a reply with your API key: \(error.localizedDescription)") }
        }
    }
}
