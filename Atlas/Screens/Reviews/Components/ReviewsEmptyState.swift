//
//  ReviewsEmptyState.swift
//  Atlas
//

import SwiftUI

/// No reviews yet (board 74 · 6): nothing to do, so no button; what will
/// show up here, and why ratings alone don't.
struct ReviewsEmptyState: View {
    let appName: String

    var body: some View {
        EmptyStateView(
            String(localized: "No reviews yet", comment: "kind:empty-state"),
            systemImage: AppWorkspaceSection.reviews.systemImage,
            text: String(localized: """
            When people review \(appName) in any country, their reviews show up here, translated, with a suggested reply in \
            their language.
            """, comment: "kind:description"),
            note: String(
                localized: "Ratings without a written review count toward the average but don’t show here.", comment: "kind:description"
            )
        )
        .accessibilityIdentifier("reviews.none")
    }
}
