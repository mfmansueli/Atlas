//
//  TraderPreviewBlock.swift
//  Atlas
//

import SwiftUI

/// The preview's "In the EU" block beside App Compliance: the trader's
/// details as they'll show on the page there, highlighted while they're
/// only suggested, or that a non-trader shows none.
struct TraderPreviewBlock: View {
    let preview: TraderPreview

    var body: some View {
        if preview != .hidden {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Divider()
                Text("In the EU")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.label2)
                content
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("appInformation.preview.trader")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch preview {
        case .hidden:
            EmptyView()
        case let .details(text, isSuggested):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Trader")
                    .foregroundStyle(Palette.label2)
                Text(text.isEmpty ? "—" : text)
                    .modifier(AppStorePreviewHighlight(isOn: isSuggested))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("appInformation.preview.trader.details")
            }
        case .nonTrader:
            note(String(localized: "Non-trader: no trader details on the page."))
        case .declaredAtApple:
            note(String(localized: "As declared in App Store Connect."))
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(Palette.label2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("appInformation.preview.trader.note")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        TraderPreviewBlock(preview: .details("Northpier Studio Ltd · 14 Harbour Road, Dublin 2 · +353 1 555 0142", isSuggested: true))
        TraderPreviewBlock(preview: .nonTrader)
    }
    .font(.subheadline)
    .padding()
    .frame(width: 236)
}
