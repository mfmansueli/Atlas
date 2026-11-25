//
//  AppSaleQueuedBox.swift
//  Atlas
//

import SwiftUI

/// What an App Price or Availability change waiting in Review & Push
/// sets, with Change… and Discard. Pushing it is the toolbar's Review &
/// Push (README — toolbar: no page has a push button of its own).
struct AppSaleQueuedBox: View {
    let text: String
    var problem: String?
    let identifier: String
    let onChange: (() -> Void)?
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Label {
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "arrow.up.circle")
                    .foregroundStyle(Palette.accentText)
            }
            .font(.callout)
            .accessibilityIdentifier("\(identifier).text")
            if let problem {
                InlineMessage.error(problem)
                    .font(.subheadline)
            }
            HStack(spacing: Spacing.small) {
                Spacer(minLength: Spacing.small)
                Button("Discard", action: onDiscard)
                    .accessibilityIdentifier("\(identifier).discard")
                if let onChange {
                    Button("Change…", action: onChange)
                        .accessibilityIdentifier("\(identifier).change")
                }
            }
            .controlSize(.regular)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, Spacing.small)
        .background(Palette.accentTint, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}
