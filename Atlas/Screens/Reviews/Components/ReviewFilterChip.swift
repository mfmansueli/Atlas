//
//  ReviewFilterChip.swift
//  Atlas
//

import SwiftUI

/// One of the list's filters: "Needs a Reply 23", filled while it's on.
struct ReviewFilterChip: View {
    let title: String
    var count: Int?
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xSmall) {
                Text(title)
                if let count {
                    Text(count, format: .number)
                        .monospacedDigit()
                        .opacity(0.75)
                }
            }
            .font(.callout)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .foregroundStyle(isOn ? Color.white : Palette.label)
            .background(isOn ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(Palette.fill1), in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? Color.clear : Palette.separator, lineWidth: 0.5))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(count.map { "\(title), \($0)" } ?? title))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    HStack {
        ReviewFilterChip(title: "Needs a Reply", count: 23, isOn: true) {}
        ReviewFilterChip(title: "1–2 Stars", isOn: false) {}
    }
    .padding()
}
