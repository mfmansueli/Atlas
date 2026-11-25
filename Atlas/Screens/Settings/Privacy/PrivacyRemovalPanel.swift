//
//  PrivacyRemovalPanel.swift
//  Atlas
//

import SwiftUI

/// "Remove All Keys and Data…", asked in place (README-DS §9, risk level
/// 4: confirm in place, naming what goes): every key, assistant and
/// unpushed change leaves this Mac, Atlas quits, and nothing changes in
/// App Store Connect.
struct PrivacyRemovalPanel: View {
    let onCancel: () -> Void
    let onRemove: () -> Void

    static var title: String {
        String(localized: "Remove all keys and data from this Mac?", comment: "kind:confirmation")
    }

    static var detail: String {
        String(localized: """
        Deletes every App Store Connect key, API key and paired assistant, and every unpushed draft, suggestion and \
        change. Atlas quits. Nothing changes in App Store Connect.
        """, comment: "kind:confirmation")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text(Self.title)
                .atlasTextStyle(.headline)
                .foregroundStyle(Palette.err)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("settings.privacy.removeAll.title")
            Text(Self.detail)
                .atlasTextStyle(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.privacy.removeAll.detail")
            HStack(spacing: Spacing.small) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("settings.privacy.removeAll.cancel")
                Button("Remove and Quit", role: .destructive, action: onRemove)
                    // Destructive (README — Design system §4): secondary, red label.
                    .destructiveButton()
                    .accessibilityIdentifier("settings.privacy.removeAll.confirm")
            }
            .controlSize(.regular)
        }
        .padding(Spacing.medium)
        .background(Palette.errTint, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.privacy.removeAll.panel")
    }
}

#Preview {
    PrivacyRemovalPanel(onCancel: {}, onRemove: {})
        .padding()
        .frame(width: 480)
}
