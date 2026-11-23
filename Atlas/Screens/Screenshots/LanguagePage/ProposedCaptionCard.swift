//
//  ProposedCaptionCard.swift
//  Atlas
//

import SwiftUI

/// A caption an assistant suggested, under the screenshots: "Screenshot 2 ·
/// caption", who suggested it and why, the caption now and suggested, and
/// Dismiss, Use and Edit, Accept. It arrives and settles like a field's
/// suggestion (effects 2 and 5).
struct ProposedCaptionCard: View {
    let caption: ProposedCaption
    /// What the caption reads now; "" reads "Empty".
    let current: String
    let isRightToLeft: Bool
    let onDismiss: () -> Void
    let onUseAndEdit: () -> Void
    let onAccept: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSettling = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.xSmall) {
                Text(caption.title)
                    .font(.body.weight(.semibold))
                Spacer(minLength: Spacing.small)
                Image(systemName: "sparkle")
                    .imageScale(.small)
                    .foregroundStyle(Palette.ai)
                    .accessibilityHidden(true)
                Text("Suggested")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.ai)
                SuggestionSourceTag(source: caption.source)
            }
            if !caption.reason.isEmpty {
                Text(caption.reason)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: Spacing.medium) {
                text(String(localized: "NOW"), current.isEmpty ? String(localized: "Empty") : current, isEmpty: current.isEmpty)
                text(String(localized: "SUGGESTED"), caption.item.headline, isSuggested: true)
            }
            HStack(spacing: Spacing.small) {
                Spacer()
                Button("Dismiss") { AIDecided.dismiss(reduceMotion: reduceMotion, commit: onDismiss) }
                    .accessibilityIdentifier("screenshots.page.caption.dismiss")
                Button("Use and Edit", action: onUseAndEdit)
                    .accessibilityIdentifier("screenshots.page.caption.useAndEdit")
                Button("Accept", action: accept)
                    .rowActionButton()
                    .accessibilityIdentifier("screenshots.page.caption.accept")
            }
            .controlSize(.regular)
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSettling ? Palette.raised : Palette.aiSurface, in: shape)
        .aiArrived(key: caption.id, arrivedAt: caption.receivedAt)
        .id(caption.id)
        .aiDecided(isSettling: isSettling)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screenshots.page.caption.\(caption.slot)")
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
    }

    private func accept() {
        AIDecided.accept(reduceMotion: reduceMotion) {
            isSettling = true
        } commit: {
            onAccept()
        }
    }

    private func text(_ label: String, _ value: String, isEmpty: Bool = false, isSuggested: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isSuggested ? AnyShapeStyle(Palette.ai) : AnyShapeStyle(Palette.label2))
            Group {
                if isSuggested {
                    SuggestedText(value, arrivalKey: caption.id, arrivedAt: caption.receivedAt)
                } else {
                    Text(value)
                }
            }
            .font(.callout)
            .foregroundStyle(isEmpty ? Palette.label3 : Palette.label)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.layoutDirection, isRightToLeft && !isEmpty ? .rightToLeft : .leftToRight)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
