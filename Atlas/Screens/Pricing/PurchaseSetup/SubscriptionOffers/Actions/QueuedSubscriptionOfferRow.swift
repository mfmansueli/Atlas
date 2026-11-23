//
//  QueuedSubscriptionOfferRow.swift
//  Atlas
//

import SwiftUI

/// An offer change waiting in Review & Push, in the Offers tab's list:
/// what it does, who proposed it, and why it can't go yet if it can't.
struct QueuedSubscriptionOfferRow: View {
    let change: PendingChange

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(change.title)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text(change.newValue)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .lineLimit(2)
            if let blocked = change.blockingMessage {
                Text(blocked)
                    .font(.subheadline)
                    .foregroundStyle(Palette.err)
                    .lineLimit(2)
            } else if change.source != .you {
                Text("Proposed by \(change.source.title)")
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pricing.offers.queued.\(change.id)")
    }
}
