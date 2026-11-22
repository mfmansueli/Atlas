//
//  AnalyticsBox.swift
//  Atlas
//

import SwiftUI

/// A raised box for one of Analytics' tables or bar lists, with an
/// optional title row.
struct AnalyticsBox<Content: View>: View {
    var title: String?
    var trailing: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            if let title {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.headline)
                    Spacer(minLength: Spacing.small)
                    if let trailing {
                        Text(trailing).font(.subheadline).foregroundStyle(Palette.label2).lineLimit(1)
                    }
                }
                .padding(.horizontal, Spacing.medium)
                .padding(.top, Spacing.small)
            }
            content()
        }
        .padding(.bottom, Spacing.xSmall)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5) }
        .accessibilityElement(children: .contain)
    }
}
