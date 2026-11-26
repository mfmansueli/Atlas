//
//  AppInformationToast.swift
//  Atlas
//

import SwiftUI

/// What an action did, at the bottom of the page for a few seconds, e.g.
/// "Saved. It’s waiting in Review & Push…". VoiceOver announces it.
struct AppInformationToast: View {
    let text: String
    let onDismiss: () -> Void

    /// The closed Autopilot bar's room at the page's bottom: the toast
    /// sits above it (0 where there's no bar).
    @Environment(\.chatCornerRoom) private var barRoom

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small + 2)
        .frame(maxWidth: 520)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
                .strokeBorder(Palette.separator2, lineWidth: 0.5)
        }
        .depth(.popover)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("appInformation.toast")
        .task(id: text) {
            AccessibilityNotification.Announcement(text).post()
            try? await Task.sleep(for: .seconds(6))
            onDismiss()
        }
        .padding(.bottom, barRoom)
    }
}

#Preview {
    AppInformationToast(text: "Saved. It’s waiting in Review & Push, where you choose whether to publish it.") {}
        .padding()
}
