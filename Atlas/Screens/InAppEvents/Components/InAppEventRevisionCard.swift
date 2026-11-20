//
//  InAppEventRevisionCard.swift
//  Atlas
//

import SwiftUI

/// An assistant's revision of a language that's written: who suggested it
/// and why, and for each text it changes, Now and Suggested with the
/// changed words marked; the texts it leaves out stay as they are.
/// Dismiss keeps them, Use and Edit puts the revision in to edit, Accept
/// queues it in Review & Push.
struct InAppEventRevisionCard: View {
    let languageName: String
    let revision: InAppEventTextSuggestion
    /// The text each field has now: queued, else App Store Connect's.
    let current: (InAppEventField) -> String
    var isRightToLeft = false
    let onDismiss: () -> Void
    let onUseAndEdit: () -> Void
    let onAccept: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                Pill(text: String(localized: "Suggested"), style: .machineTranslated)
                Text("\(languageName): revision")
                    .font(.headline)
                SuggestionSourceTag(source: .assistant(client: revision.source))
                Spacer(minLength: 0)
            }
            Text(revision.why)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("events.revision.why")
            ForEach(revision.fields) { field in
                fieldRows(field)
            }
            if let over = revision.overLimit {
                InlineMessage.warning(String(localized: "\(over.field.title) is \(over.count) characters; the limit is \(over.field.limit)."))
                    .font(.caption)
            }
            HStack(spacing: Spacing.xSmall) {
                Text(keptText)
                    .font(.caption2)
                    .foregroundStyle(Palette.label2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Dismiss", action: onDismiss)
                    .accessibilityIdentifier("events.revision.dismiss")
                Button("Use and Edit", action: onUseAndEdit)
                    .accessibilityIdentifier("events.revision.useAndEdit")
                Button("Accept", action: onAccept)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("events.revision.accept")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.machineTranslatedTint, in: shape)
        .overlay(shape.strokeBorder(Palette.machineTranslatedMark.opacity(contrast == .increased ? 0.8 : 0.35), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Revision of \(languageName) from \(revision.source)"))
        .accessibilityIdentifier("events.revision")
    }

    /// "Event Name and Short Description stay as they are."
    private var keptText: String {
        let kept = InAppEventField.allCases.filter { !revision.suggests($0) }
        guard !kept.isEmpty else { return "" }
        return String(localized: "\(kept.map(\.title).formatted(.list(type: .and))) stay as they are.")
    }

    private func fieldRows(_ field: InAppEventField) -> some View {
        let diff = TextWordDiff(from: current(field), to: revision.text(field))
        return VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Text(field.title)
                .font(.caption.weight(.semibold))
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: Spacing.xxSmall) {
                GridRow {
                    label(String(localized: "NOW"), color: Palette.label2)
                    MarkedDiffText(diff: diff, side: .now)
                        .font(.caption)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
                        .accessibilityLabel(Text(current(field)))
                        .accessibilityIdentifier("events.revision.\(field.rawValue).now")
                }
                GridRow {
                    label(String(localized: "SUGGESTED"), color: Palette.machineTranslated)
                    MarkedDiffText(diff: diff, side: .suggested)
                        .font(.callout)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, isRightToLeft ? .rightToLeft : .leftToRight)
                        .accessibilityLabel(Text(revision.text(field)))
                        .accessibilityValue(Text(changedWords(diff)))
                        .accessibilityIdentifier("events.revision.\(field.rawValue).suggested")
                }
            }
            Text("\(revision.text(field).count) / \(field.limit)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Palette.label2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("events.revision.\(field.rawValue)")
    }

    /// "Changed: December 2", for VoiceOver.
    private func changedWords(_ diff: TextWordDiff) -> String {
        let added = diff.addedWords.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return added.isEmpty ? "" : String(localized: "Changed: \(added.joined(separator: ", "))")
    }

    private func label(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: 74, alignment: .leading)
    }
}
