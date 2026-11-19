//
//  SettingsLockedRow.swift
//  Atlas
//

import SwiftUI

/// Something Atlas will never do, shown instead of left out: a lock, the
/// thing, an optional line under it, and "Always" or "Never" on the right.
struct SettingsLockedRow: View {
    let title: LocalizedStringKey
    var caption: String?
    var trailing: LocalizedStringKey? = "Always"

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(Palette.label3)
                .frame(width: 14)
                .accessibilityHidden(true)
            SettingsRowLabel(title: title, caption: caption)
            Spacer(minLength: Spacing.medium)
            if let trailing {
                Text(trailing)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
