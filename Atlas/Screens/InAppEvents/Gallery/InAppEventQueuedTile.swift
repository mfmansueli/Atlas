//
//  InAppEventQueuedTile.swift
//  Atlas
//

import SwiftUI

/// A new event waiting in Review & Push, in the gallery: its name and
/// dates, and that its languages are written once it's pushed. It has no
/// page until App Store Connect creates it.
struct InAppEventQueuedTile: View {
    let change: PendingChange

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Palette.fill1)
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay {
                    VStack(spacing: Spacing.xxSmall) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Palette.label3)
                        Text("Created when you push")
                            .font(.subheadline)
                            .foregroundStyle(Palette.label2)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Palette.separator, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
                .padding(.bottom, Spacing.xxSmall)
            HStack(spacing: Spacing.xSmall) {
                Text(change.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Pill(text: String(localized: "Not pushed"), style: .outline)
                    .fixedSize()
            }
            HStack(spacing: Spacing.xxSmall) {
                UnsavedDot(size: 6)
                Text(change.newValue)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
            }
            Text("Push it in Review & Push; then its languages are written here.")
                .font(.system(size: 10))
                .foregroundStyle(Palette.label2)
                .lineLimit(2)
        }
        .padding(.horizontal, Spacing.small)
        .padding(.top, Spacing.small)
        .padding(.bottom, 10)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.separator2, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("events.queued.\(change.id)")
    }
}
