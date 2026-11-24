//
//  NominationConfirmSheet.swift
//  Atlas
//

import SwiftUI

/// Submit… and Archive…'s confirmation (risk level 3): what, who, when and
/// how to undo, then Add to Review & Push. Nothing is sent until the
/// person pushes; a submit can't be withdrawn, only archived later.
struct NominationConfirmSheet: View {
    let sheet: NominationSheet
    let nomination: Nomination
    @Bindable var viewModel: NominationsViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("nominations.sheet.title")
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
            }
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.large, verticalSpacing: Spacing.small) {
                ForEach(rows, id: \.0) { row in
                    GridRow {
                        Text(row.0)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Palette.label2)
                        Text(row.1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if isSubmit, let days = nomination.content.daysUntilStart(now: viewModel.now()), days >= 0, days < NominationNeed.closeDays {
                InlineMessage.warning(String(localized: "Starts \(NominationDayText.relative(days)). Apple suggests a few weeks ahead; you can still submit.", comment: "kind:banner"))
                    .accessibilityIdentifier("nominations.sheet.soon")
            }
            Text(isSubmit
                ? String(localized: "Apple doesn’t say whether it’s featured.", comment: "kind:description")
                : String(localized: "Nothing is sent until you push.", comment: "kind:description"))
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    viewModel.sheet = nil
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("nominations.sheet.cancel")
                Button("Add to Review & Push") {
                    if isSubmit { viewModel.confirmSubmit(nomination.id) } else { viewModel.confirmArchive(nomination.id) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("nominations.sheet.confirm")
            }
            .buttonBorderShape(.capsule)
        }
        .padding(Spacing.xxLarge)
        .frame(width: 540)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isSubmit ? "nominations.sheet.submit" : "nominations.sheet.archive")
    }

    private var isSubmit: Bool {
        if case .submit = sheet { return true }
        return false
    }

    private var title: String {
        isSubmit
            ? String(localized: "Submit to Apple’s Editors", comment: "kind:sheet-title")
            : String(localized: "Archive This Nomination", comment: "kind:sheet-title")
    }

    private var subtitle: String {
        isSubmit
            ? String(localized: "It goes when you push. After you push, you can only archive it.", comment: "kind:description")
            : String(localized: "It moves to Archived in App Store Connect when you push.", comment: "kind:description")
    }

    private var rows: [(String, String)] {
        let content = nomination.content
        let when = String(localized: "The next time you push from Review & Push.", comment: "kind:description")
        if isSubmit {
            let start = content.publishStart.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—"
            let what = [String(localized: "“\(content.trimmedName)”", comment: "kind:other"), content.type?.title,
                        String(localized: "from \(start)", comment: "kind:other")].compactMap(\.self).joined(separator: " · ")
            let team = viewModel.context.teamName.map { String(localized: "Apple’s editorial team, from \($0).", comment: "kind:description") }
                ?? String(localized: "Apple’s editorial team.", comment: "kind:description")
            return [
                (String(localized: "What", comment: "kind:field-label"), what),
                (String(localized: "Goes to", comment: "kind:field-label"), team),
                (String(localized: "When", comment: "kind:field-label"), when),
                (String(localized: "Undo", comment: "kind:field-label"),
                 String(localized: "You can only archive it later. It can’t be withdrawn or edited.", comment: "kind:description")),
            ]
        }
        let submitted = nomination.submittedDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "—"
        return [
            (String(localized: "What", comment: "kind:field-label"), String(localized: "“\(content.trimmedName)” · submitted on \(submitted)", comment: "kind:other")),
            (
                String(localized: "Who sees it", comment: "kind:field-label"),
                String(localized: "Your team, read-only, under Archived.", comment: "kind:description")
            ),
            (String(localized: "When", comment: "kind:field-label"), when),
            (String(localized: "Undo", comment: "kind:field-label"), String(localized: "Atlas can’t unarchive it.", comment: "kind:description")),
        ]
    }
}
