//
//  SectionSymbol.swift
//  Atlas
//

import SwiftUI

/// A section's or Settings pane's SF Symbol in its system colour, with no
/// tile behind it (README — Design system §13, board 72), centred in a
/// fixed column so the names beside it line up.
struct SectionSymbol: View {
    let style: SectionStyle
    /// Overview's rows draw it at Title 3; everywhere else it follows the
    /// text beside it.
    var isLarge = false

    var body: some View {
        Image(systemName: style.symbol)
            .font(isLarge ? .title3 : nil)
            .foregroundStyle(style.color)
            .frame(width: isLarge ? Metrics.largeSymbolColumn : Metrics.symbolColumn)
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(alignment: .leading) {
        HStack {
            ForEach([SectionStyle.overview, .storePage, .screenshots, .productPages, .inAppEvents], id: \.self) { SectionSymbol(style: $0) }
        }
        HStack {
            ForEach([SectionStyle.nominations, .appInformation, .pricing, .reviews, .analytics], id: \.self) {
                SectionSymbol(style: $0, isLarge: true)
            }
        }
    }
    .padding()
}
