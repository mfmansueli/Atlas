//
//  InAppEventListRow.swift
//  Atlas
//

import SwiftUI

/// One event in the list: its card image with the badge, its reference
/// name, its dates and its status.
struct InAppEventListRow: View {
    let event: InAppEvent
    let status: InAppEventStatus
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                InAppEventArtwork(event: event)
                    .frame(height: 76)
                    .overlay(alignment: .topLeading) {
                        if let badge = event.badge {
                            Text(badge.title.uppercased())
                                .font(.system(size: 9.5, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(.white.opacity(0.95))
                                .padding(.leading, Spacing.small)
                                .padding(.top, 7)
                        }
                    }
                Text(event.referenceName)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: Spacing.xSmall) {
                    Text(event.datesText)
                        .font(.caption)
                        .foregroundStyle(Palette.label2)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Pill(text: status.title, style: status.pillStyle)
                        .fixedSize()
                }
            }
            .padding(7)
            .background(isSelected ? Palette.fill2 : .clear, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(isSelected ? Palette.separator2 : .clear, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(event.referenceName), \(status.title), \(event.datesText)"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
