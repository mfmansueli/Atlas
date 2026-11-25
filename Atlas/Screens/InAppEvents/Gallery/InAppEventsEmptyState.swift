//
//  InAppEventsEmptyState.swift
//  Atlas
//

import SwiftUI

/// No In-App Events yet (board 74 · 3): what an event is and how to start,
/// naming New Event… at the top and the toolbar's Suggest an Event…, with
/// App Review and the 31 days in the small line. No button of its own.
struct InAppEventsEmptyState: View {
    let appName: String

    var body: some View {
        EmptyStateView(
            String(localized: "No In-App Events yet", comment: "kind:empty-state"),
            systemImage: AppWorkspaceSection.inAppEvents.systemImage,
            text: String(localized: """
            An In-App Event is a card on the App Store, in search and on Today, for something timely in \(appName): a \
            challenge, a new season, a live session. Click New Event to start one, or Suggest an Event to have your \
            assistant draft it.
            """, comment: "kind:description"),
            note: String(localized: "Each event goes to App Review and can run for up to 31 days.", comment: "kind:description")
        )
        .accessibilityIdentifier("events.empty")
    }
}
