//
//  ReviewsDebugLaunch.swift
//  Atlas
//

#if DEBUG
import Foundation

/// The state a Reviews DEBUG scene opens in: the filter, a review shown as
/// written, one being edited, and Reply to All open.
struct ReviewsDebugLaunch {
    /// Taken by the section when it builds its view model.
    @MainActor static var pending: ReviewsDebugLaunch?

    var filter = ReviewFilter.needsReply
    /// Reviews shown as written, although translation is on.
    var originals: [AppReview.ID] = []
    /// The review whose reply is being edited, and the draft.
    var editing: AppReview.ID?
    var draft: String?
    /// Reviews whose suggested reply was sent a moment ago.
    var sent: [AppReview.ID] = []
    /// The group Reply to All opens for.
    var bulkTheme: ReviewTheme.ID?

    @MainActor
    func apply(to model: ReviewsViewModel) {
        model.filter = filter
        for id in originals { model.translationOverrides[id] = false }
        for id in sent {
            guard let review = model.archive.review(id: id), let suggestion = model.archive.suggestions[id] else { continue }
            model.store.setReply(ReviewReply(id: "debug-reply-\(id)", text: suggestion.text, date: DebugReviewsData.today), reviewID: review.id, for: model.app.id)
            model.sentNow.insert(id)
            model.keptVisible.insert(id)
        }
        if let editing, let review = model.archive.review(id: editing) {
            model.startEditing(review)
            if let draft { model.drafts[editing] = draft }
        }
        if let bulkTheme, let theme = model.archive.themes.first(where: { $0.id == bulkTheme }) {
            model.openBulk(theme)
        }
    }
}
#endif
