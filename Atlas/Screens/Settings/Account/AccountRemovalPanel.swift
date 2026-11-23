//
//  AccountRemovalPanel.swift
//  Atlas
//

import SwiftUI

/// Removing a key, asked in place on that key (board 48): exactly what is
/// lost, and that nothing changes in App Store Connect.
struct AccountRemovalPanel: View {
    let name: String
    /// From the key's last check; nil before one.
    let appCount: Int?
    let onCancel: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Remove \(name)?")
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.err)
                .accessibilityIdentifier("settings.remove.title")
            Text(detail)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.remove.detail")
            HStack(spacing: Spacing.small) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("settings.remove.cancel")
                Button("Remove Key", role: .destructive, action: onRemove)
                    // Destructive (README — Design system §4): secondary, red label.
                    .destructiveButton()
                    .accessibilityIdentifier("settings.remove.confirm")
            }
            .controlSize(.regular)
        }
        .padding(Spacing.medium)
        .background(Palette.errTint, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.remove.panel")
    }

    private var detail: String {
        let apps = switch appCount {
        case nil: String(localized: "Its apps leave Atlas.")
        case 1: String(localized: "Its app leaves Atlas.")
        case let count?: String(localized: "Its \(count) apps leave Atlas.")
        }
        return apps + " " + String(localized: """
        Deletes the key from this Mac’s Keychain. Unpushed changes stay. Nothing changes in App Store Connect.
        """)
    }
}
