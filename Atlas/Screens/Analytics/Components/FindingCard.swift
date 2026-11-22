//
//  FindingCard.swift
//  Atlas
//

import SwiftUI

/// One finding: who saw it, what was seen, the numbers behind it, how sure
/// it is, and one place to act.
struct FindingCard: View {
    let finding: AnalyticsFinding
    var isNew = false
    /// "A change is waiting in Review & Push, top right": the toolbar's
    /// button is the only push (board 57).
    var state: String?
    let onDismiss: () -> Void
    let onSecondAction: () -> Void
    let onAction: () -> Void

    var body: some View {
        Card(padding: Spacing.medium) {
            HStack(spacing: Spacing.small) {
                FindingSourceMark(source: finding.source)
                Pill(text: finding.area.title, style: .outline)
                if isNew { Pill(text: String(localized: "New"), style: .accent) }
                Spacer(minLength: Spacing.small)
                Pill(text: finding.sureness)
                    .help(finding.surenessDetail)
            }
            Text(finding.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(finding.why)
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            if !finding.numbers.isEmpty {
                FlowLayout(spacing: Spacing.small) {
                    ForEach(finding.numbers, id: \.self) { number in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(number.label).font(.caption).foregroundStyle(Palette.label2)
                            Text(number.value).font(.callout.weight(.semibold)).monospacedDigit()
                            if let note = number.note, !note.isEmpty {
                                Text(note).font(.caption).foregroundStyle(Palette.label2).monospacedDigit()
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            Text("How sure: \(finding.surenessDetail)")
                .font(.caption)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
            if let read = finding.read, !read.isEmpty {
                Text("Read: \(read.joined(separator: " · "))")
                    .font(.caption.monospaced())
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
                    .accessibilityIdentifier("analytics.finding.read.\(finding.id)")
            }
            if let state {
                HStack(spacing: Spacing.small) {
                    Text(state).font(.callout)
                    Spacer(minLength: Spacing.small)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Palette.accentTint, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            }
            HStack(spacing: Spacing.small) {
                Spacer()
                Button("Dismiss", action: onDismiss)
                if let second = finding.secondAction {
                    Button(second.title, action: onSecondAction)
                }
                Button(finding.action.title, action: onAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("analytics.finding.action")
            }
            .controlSize(.small)
        }
        .accessibilityIdentifier("analytics.finding.\(finding.id)")
    }
}
