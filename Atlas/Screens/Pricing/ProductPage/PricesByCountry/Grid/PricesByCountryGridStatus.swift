//
//  PricesByCountryGridStatus.swift
//  Atlas
//

import SwiftUI

/// The banner's place while Apple's price points are read, or after they
/// failed: "Checking Apple’s prices…" as a plain grey line, with no
/// surface and no AI motion (board 76: loading isn't a banner, and Atlas
/// reading Apple isn't the assistant at work); or why they didn't load,
/// red like every non-AI failure, with Try Again. Today's prices show in
/// the table under it all along: they're Apple's already.
struct PricesByCountryGridStatus: View {
    let state: PriceGridState
    let onRetry: () -> Void

    var body: some View {
        switch state {
        case .checking:
            checking
        case let .failed(copy):
            failed(copy.text)
        case .ready:
            EmptyView()
        }
    }

    private var checking: some View {
        LoadingLine(text: PriceGridState.checkingText)
            .padding(.vertical, Spacing.xxSmall)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(PriceGridState.checkingText))
            .accessibilityIdentifier("countries.grid.checking")
    }

    private func failed(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            InlineMessage.error(text)
                .accessibilityIdentifier("countries.grid.error.text")
            Spacer(minLength: Spacing.small)
            Button(String(localized: "Try Again", comment: "kind:button"), action: onRetry)
                .secondaryButton()
                .accessibilityIdentifier("countries.grid.retry")
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("countries.grid.error")
    }
}
