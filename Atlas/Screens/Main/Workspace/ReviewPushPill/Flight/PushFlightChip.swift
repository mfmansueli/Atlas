//
//  PushFlightChip.swift
//  Atlas
//

import SwiftUI

/// The blue chip that flies to Review & Push (board 80): the push arrow
/// and the name of what was accepted, “What's New · German”. Blue: the
/// person did this.
struct PushFlightChip: View {
    let label: String

    var body: some View {
        HStack(spacing: Spacing.xxSmall) {
            Image(systemName: "arrow.up.circle")
            Text(label)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(Color.white)
        .padding(.leading, Spacing.small)
        .padding(.trailing, Spacing.medium)
        .frame(height: Metrics.pushChipHeight)
        .background(Palette.accent, in: Capsule())
        .depth(.popover)
        .frame(maxWidth: Metrics.pushChipMaxWidth)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityHidden(true)
    }
}

#Preview {
    PushFlightChip(label: "What’s New · German")
        .padding(Spacing.xxLarge)
}
