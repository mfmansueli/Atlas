//
//  SectionHeader.swift
//  Atlas
//

import SwiftUI

/// The top of a section's page, under the toolbar that names it (board
/// 57): one sentence about what it changes on the App Store, and the
/// page's own controls on the right. The section's title and state are in
/// the toolbar, not here.
struct SectionHeader<Trailing: View>: View {
    let subtitle: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(Palette.label2)
                .lineLimit(2)
                .truncationMode(.tail)
                .accessibilityIdentifier("section.description")
            Spacer(minLength: Spacing.small)
            HStack(spacing: Spacing.small) {
                trailing()
            }
            .fixedSize()
        }
        .frame(minHeight: 32)
    }
}

#Preview {
    SectionHeader(subtitle: "The words on Lumen’s App Store page and in search, in every language.") {
        Button("Translate Missing…") {}
    }
    .padding()
    .frame(width: 720)
}
