//
//  NominationsEmptyState.swift
//  Atlas
//

import SwiftUI

/// No nominations yet (board 74 · 1): what a nomination is and how to
/// start, naming New Nomination… at the top and the toolbar's Suggest a
/// Nomination…, with what Apple says back (nothing) in the small line. No
/// button of its own: both are already on screen.
struct NominationsEmptyState: View {
    var body: some View {
        EmptyStateView(
            String(localized: "No nominations yet", comment: "kind:empty-state"),
            systemImage: AppWorkspaceSection.nominations.systemImage,
            text: String(localized: """
            A nomination tells Apple’s editors about a launch, a big update or an In-App Event before it happens. Click New \
            Nomination to start one, or Suggest a Nomination to have your assistant draft it.
            """, comment: "kind:description"),
            note: String(localized: """
            Send it a few weeks ahead, up to 3 months for a launch. Apple doesn’t reply, and a nomination isn’t a promise of \
            featuring.
            """, comment: "kind:description")
        )
        .accessibilityIdentifier("nominations.empty")
    }
}
