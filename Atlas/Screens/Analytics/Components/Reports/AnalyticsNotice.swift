//
//  AnalyticsNotice.swift
//  Atlas
//

import SwiftUI

/// A banner inside an Analytics view: a warning worth acting on, or a note
/// about where the numbers come from, with up to two buttons.
struct AnalyticsNotice: View {
    enum Tone { case warning, info }

    let tone: Tone
    let text: String
    var primary: (title: String, action: () -> Void)?
    var secondary: (title: String, action: () -> Void)?
    var identifier: String?

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.small) {
            Image(systemName: tone == .warning ? "exclamationmark.triangle.fill" : "info.circle")
                .foregroundStyle(tone == .warning ? Palette.warningMark : Palette.label2)
                .accessibilityHidden(true)
            Text(text)
                .font(.callout)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let secondary {
                Button(secondary.title, action: secondary.action).controlSize(.small)
            }
            if let primary {
                Button(primary.title, action: primary.action).controlSize(.small)
            }
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(
            tone == .warning ? Palette.warningTint : Palette.fill1,
            in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier ?? "")
    }
}
