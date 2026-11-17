//
//  AccessibilityLoadErrorView.swift
//  Atlas
//

import SwiftUI

/// The declarations didn't load: what failed, the status, Apple's code and
/// the request, and Try Again.
struct AccessibilityLoadErrorView: View {
    let message: String
    let requestLine: String?
    /// Where it's used, for its identifiers: App Compliance shows it too.
    var identifier = "appInformation.accessibility"
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(Palette.danger)
                .accessibilityHidden(true)
            Text("\(Text(message).fontWeight(.semibold))\(Text(requestLine.map { "  \($0)" } ?? "").font(.caption.monospaced()).foregroundStyle(Palette.label2))")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Spacer(minLength: Spacing.medium)
            Button(String(localized: "Try Again"), action: onRetry)
                .controlSize(.small)
                .accessibilityIdentifier("\(identifier).retry")
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small + 2)
        .background(Palette.dangerTint, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(identifier).error")
    }
}

#Preview {
    AccessibilityLoadErrorView(
        message: "Couldn’t load accessibility declarations.",
        requestLine: "500 · UNEXPECTED_ERROR · GET /v1/apps/6474829310/accessibilityDeclarations"
    ) {}
        .frame(width: 700)
        .padding()
}
