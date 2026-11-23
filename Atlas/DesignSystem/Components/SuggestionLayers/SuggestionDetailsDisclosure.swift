//
//  SuggestionDetailsDisclosure.swift
//  Atlas
//

import SwiftUI

/// The third layer of a decision (README-DS §9): every number, the source
/// and the risk, folded under "Details" at the end of the card, after its
/// actions. Opens in place.
struct SuggestionDetailsDisclosure: View {
    let details: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: Spacing.xxSmall) {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                    Text(String(localized: "Details", comment: "kind:button"))
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(Palette.label2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(isExpanded
                    ? String(localized: "Expanded", comment: "kind:accessibility-label")
                    : String(localized: "Collapsed", comment: "kind:accessibility-label")))
            .accessibilityIdentifier("suggestion.details.toggle")
            if isExpanded {
                Text(details)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("suggestion.details")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SuggestionDetailsDisclosure(
        details: "Lifetime costs 16 months of Monthly; 12 is common for journaling apps. 9 of the last 220 reviews mention the price."
    )
    .padding()
    .frame(width: 420)
}
