//
//  InAppEventDatesSuggestionView.swift
//  Atlas
//

import SwiftUI

/// Under a draft's dates, when an assistant suggests other dates than the
/// ones the person queued: who and why, the person's and the suggested
/// "Shows from", "Starts" and "Ends" side by side (the ones that differ
/// marked), and Dismiss (the person's stay) or Accept (the suggested ones
/// replace them). Nothing changes until the person picks.
struct InAppEventDatesSuggestionView: View {
    let yours: InAppEventDates
    let suggested: InAppEventDates
    let alternative: ChangeAlternative
    var format = InAppEventDateText.current
    let onDismiss: () -> Void
    let onAccept: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.banner, style: .continuous)
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                Pill(text: String(localized: "Suggested"), style: .machineTranslated)
                if case let .assistant(client) = alternative.source {
                    SuggestionSourceTag(source: .assistant(client: client))
                }
                Text(alternative.note ?? String(localized: "Other dates than the ones you set."))
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("events.details.dates.alternative.reason")
            }
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: Spacing.xxSmall) {
                GridRow {
                    Color.clear.frame(width: 74, height: 1)
                    heading(String(localized: "YOURS"), color: Palette.label2)
                    heading(String(localized: "SUGGESTED"), color: Palette.machineTranslated)
                }
                ForEach(InAppEventDateField.allCases) { field in
                    let differs = yours[field] != suggested[field]
                    GridRow {
                        Text(field.title)
                            .font(.subheadline)
                            .foregroundStyle(Palette.label2)
                            .frame(width: 74, alignment: .leading)
                        Text(format.date(yours[field]))
                            .font(.subheadline)
                            .foregroundStyle(Palette.label2)
                            .strikethrough(differs, color: Palette.label3)
                            .accessibilityIdentifier("events.details.dates.alternative.\(field.rawValue).yours")
                        Text(format.date(suggested[field]))
                            .font(.callout.weight(differs ? .semibold : .regular))
                            .foregroundStyle(differs ? AnyShapeStyle(Palette.machineTranslated) : AnyShapeStyle(Palette.label))
                            .accessibilityLabel(Text(differs ? "\(field.title): \(format.date(suggested[field])), changed" : "\(field.title): \(format.date(suggested[field]))"))
                            .accessibilityIdentifier("events.details.dates.alternative.\(field.rawValue)")
                    }
                }
            }
            if let blocked = alternative.blockedReason {
                InlineMessage.warning(blocked)
                    .font(.subheadline)
            }
            HStack(spacing: Spacing.xSmall) {
                Text("Your dates stay until you pick.")
                    .font(.caption2)
                    .foregroundStyle(Palette.label2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Dismiss", action: onDismiss)
                    .help("Keep your dates")
                    .accessibilityIdentifier("events.details.dates.alternative.dismiss")
                Button("Accept", action: onAccept)
                    .buttonStyle(.borderedProminent)
                    .help("Use these dates instead of yours")
                    .accessibilityIdentifier("events.details.dates.alternative.accept")
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.machineTranslatedTint, in: shape)
        .overlay(shape.strokeBorder(Palette.machineTranslatedMark.opacity(contrast == .increased ? 0.8 : 0.35), lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Dates suggested by \(alternative.source.title)"))
        .accessibilityIdentifier("events.details.dates.alternative")
    }

    private func heading(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
    }
}
