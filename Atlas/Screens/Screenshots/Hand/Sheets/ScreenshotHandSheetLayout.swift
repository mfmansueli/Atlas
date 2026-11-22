//
//  ScreenshotHandSheetLayout.swift
//  Atlas
//

import SwiftUI

/// The frame every sheet of Screenshots by hand shares: the title and what
/// it's for, the content, and at the bottom what a push does with Cancel
/// and the sheet's button.
struct ScreenshotHandSheetLayout<Content: View>: View {
    @Bindable var viewModel: ScreenshotsViewModel
    let title: String
    let subtitle: String
    let okTitle: String
    var okRole: ButtonRole?
    let isOKDisabled: Bool
    @ViewBuilder var content: () -> Content
    let onOK: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.label2)
            }
            .padding([.horizontal, .top], Spacing.xLarge)
            .padding(.bottom, Spacing.medium)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.xLarge)
                .padding(.bottom, Spacing.medium)
            }
            Divider()
            HStack(spacing: Spacing.small) {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(Palette.label2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Cancel") { viewModel.handSheet = nil }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("screenshots.hand.sheet.cancel")
                Button(okTitle, role: okRole, action: onOK)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isOKDisabled)
                    .accessibilityIdentifier("screenshots.hand.sheet.ok")
            }
            .padding(Spacing.large)
        }
        .frame(width: 620)
        .frame(minHeight: 300, maxHeight: 620)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.hand.sheet")
    }

    private var footer: String {
        let version = viewModel.context.version.versionString
        guard !version.isEmpty else { return String(localized: "Nothing changes on the App Store until you push.") }
        return String(localized: "Nothing changes on the App Store until you push. Screenshots go out with version \(version).")
    }
}
