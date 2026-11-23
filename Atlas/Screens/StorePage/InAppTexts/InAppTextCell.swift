//
//  InAppTextCell.swift
//  Atlas
//

import SwiftUI

/// One in-app text: the value and its counter (red over the limit), or an
/// outlined "Missing", with a warning sign when App Review would reject
/// the text. Clicking opens a popover to edit it, which says why.
struct InAppTextCell: View {
    let model: InAppTextsViewModel
    let column: InAppTextColumn
    let locale: StoreLocale

    @State private var isEditing = false

    var body: some View {
        let value = model.value(column, in: locale)
        let counter = model.counter(column, in: locale)
        let issues = model.guidelineIssues(column, in: locale)
        Button {
            isEditing = true
        } label: {
            Group {
                if value.isEmpty {
                    Text("Missing")
                        .foregroundStyle(Palette.label2)
                        .frame(maxWidth: .infinity, minHeight: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                                .strokeBorder(Palette.separator2, lineWidth: 1)
                        )
                } else {
                    HStack(spacing: Spacing.xSmall) {
                        if model.isPending(column, in: locale) {
                            UnsavedDot(size: 6)
                        }
                        Text(value)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .environment(\.layoutDirection, locale.isRTL ? .rightToLeft : .leftToRight)
                        if !issues.isEmpty {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(Palette.warn)
                                .help(issues.map(\.message).joined(separator: "\n"))
                                .accessibilityIdentifier("storePage.inAppGuideline.\(locale.code).\(column.id)")
                        }
                        if counter.isOverLimit {
                            Pill(text: "\(counter.count)/\(counter.limit.maximum)", style: .danger)
                        } else {
                            Text(verbatim: "\(counter.count)/\(counter.limit.maximum)")
                                .font(.subheadline.monospaced())
                                .foregroundStyle(Palette.label2)
                        }
                    }
                }
            }
            .font(.callout)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel(value: value, counter: counter, issues: issues)))
        .accessibilityIdentifier("storePage.inAppCell.\(locale.code).\(column.id)")
        .popover(isPresented: $isEditing, arrowEdge: .bottom) {
            editor
        }
    }

    private var editor: some View {
        let counter = model.counter(column, in: locale)
        return VStack(alignment: .leading, spacing: Spacing.small) {
            Text("\(locale.name) · \(column.title)")
                .font(.body.weight(.semibold))
            TextField(column.title, text: Binding {
                model.value(column, in: locale)
            } set: { value in
                model.edit(column, in: locale, to: value)
            })
            .textFieldStyle(.roundedBorder)
            .labelsHidden()
            .environment(\.layoutDirection, locale.isRTL ? .rightToLeft : .leftToRight)
            .accessibilityIdentifier("storePage.inAppEditor")
            HStack {
                if let message = ListingFieldValidator.validate(model.value(column, in: locale), for: column.field).message {
                    InlineMessage(text: message, systemImage: "exclamationmark.triangle", tint: Palette.err)
                        .font(.subheadline)
                }
                Spacer()
                Text(counter.text)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(counter.isOverLimit ? Palette.err : Palette.label2)
            }
            let issues = model.guidelineIssues(column, in: locale)
            if !issues.isEmpty {
                InlineMessage.warning(issues.map(\.message).joined(separator: "\n"))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("storePage.inAppEditorGuideline")
            }
            HStack {
                Spacer()
                Button("Done") { isEditing = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.large)
        .frame(width: 340)
    }

    private func accessibilityLabel(value: String, counter: ListingFieldCounter, issues: [StoreTextGuidelineIssue]) -> String {
        let title = "\(locale.name), \(column.title)"
        guard !value.isEmpty else { return "\(title): " + String(localized: "missing") }
        let label = "\(title): \(value), \(counter.accessibilityLabel)"
        return issues.isEmpty ? label : label + ". " + issues.map(\.message).joined(separator: " ")
    }
}
