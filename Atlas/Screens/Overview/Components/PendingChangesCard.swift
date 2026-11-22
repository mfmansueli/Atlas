//
//  PendingChangesCard.swift
//  Atlas
//

import SwiftUI

/// How many of this app's changes wait in Review & Push, which is in the
/// toolbar: the card says where, and has no push of its own (board 57).
struct PendingChangesCard: View {
    let count: Int

    var body: some View {
        Card {
            OverviewCardTitle(title: String(localized: "Pending changes"))
            if count > 0 {
                HStack(spacing: 6) {
                    UnsavedDot()
                    Text(count == 1 ? String(localized: "1 waiting to be pushed") : String(localized: "\(count) waiting to be pushed"))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                Text("They wait in Review & Push, top right.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            } else {
                Text("Nothing waiting")
                    .font(.title3.weight(.semibold))
                Text("Edits and accepted suggestions from every section collect here until you push them.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("overview.pendingChangesCard")
    }
}
