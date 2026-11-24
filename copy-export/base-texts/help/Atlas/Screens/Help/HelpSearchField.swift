//
//  HelpSearchField.swift
//  Atlas
//

import SwiftUI

/// "Search Help", in the sidebar and on the home page, with a clear
/// button.
struct HelpSearchField: View {
    @Binding var query: String
    let identifier: String

    var body: some View {
        HStack(spacing: Spacing.xSmall) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            TextField("Search Help", text: $query)
                .textFieldStyle(.plain)
                .accessibilityIdentifier(identifier)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Palette.label3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear Search"))
            }
        }
        .padding(.horizontal, Spacing.small)
        .padding(.vertical, 6)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field))
    }
}
