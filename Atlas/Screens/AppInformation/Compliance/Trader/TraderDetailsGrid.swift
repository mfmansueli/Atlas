//
//  TraderDetailsGrid.swift
//  Atlas
//

import SwiftUI

/// A trader's name, address, phone and email: as text, or as fields while
/// they're edited. A detail nobody filled in reads "Add it".
struct TraderDetailsGrid: View {
    let details: TraderDetails
    var isEditing = false
    var onChange: (String, TraderDetailField) -> Void = { _, _ in }

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: Spacing.xxSmall) {
            ForEach(TraderDetailField.allCases) { field in
                GridRow {
                    Text(field.title)
                        .font(.subheadline)
                        .foregroundStyle(Palette.label2)
                        .frame(width: 60, alignment: .leading)
                    value(field)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private func value(_ field: TraderDetailField) -> some View {
        if isEditing {
            TextField(field.title, text: Binding(get: { details[field] }, set: { onChange($0, field) }))
                .textFieldStyle(.roundedBorder)
                .controlSize(.regular)
                .labelsHidden()
                .accessibilityLabel(Text(field.title))
                .accessibilityIdentifier("appInformation.compliance.trader.\(field.rawValue)")
        } else {
            let text = details[field].trimmingCharacters(in: .whitespacesAndNewlines)
            Text(text.isEmpty ? String(localized: "Add it") : text)
                .font(.callout)
                .foregroundStyle(text.isEmpty ? Palette.label3 : Palette.label)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("appInformation.compliance.trader.\(field.rawValue)")
        }
    }
}

#Preview {
    let details = TraderDetails(name: "Northpier Studio Ltd", address: "", phone: "+353 1 555 0142", email: "support@northpier.dev")
    VStack(alignment: .leading, spacing: 16) {
        TraderDetailsGrid(details: details)
        TraderDetailsGrid(details: details, isEditing: true)
    }
    .padding()
    .frame(width: 480)
}
