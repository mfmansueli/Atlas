//
//  BreakdownProceedsBanner.swift
//  Atlas
//

import SwiftUI

/// Break It Down opened from the Overview's Proceeds number (board 92): a
/// neutral banner saying what the amount is and where it is in the table,
/// closed with its ✕.
struct BreakdownProceedsBanner: View {
    let explanation: String
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: StatusSymbol.info.symbol)
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            Text("\(Text(BreakdownProceedsText.title).fontWeight(.semibold)) \(Text(explanation)) \(Text(BreakdownProceedsText.whereToLook))")
                .atlasTextStyle(.callout)
                .foregroundStyle(Palette.label)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Palette.label2)
            .help(Text("Close", comment: "kind:tooltip · proceeds banner"))
            .accessibilityLabel(Text("Close", comment: "kind:button · proceeds banner"))
            .accessibilityIdentifier("analytics.breakdown.proceedsBanner.close")
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.banner))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analytics.breakdown.proceedsBanner")
    }
}
