//
//  PriceTestSuggestionCard.swift
//  Atlas
//

import SwiftUI

/// A price test the assistant suggested (board 76, `pt-cc`), in Results:
/// title, why, how sure and who suggested it, in the assistant's colour.
/// Set Up Test… opens the sheet filled in; the person starts the test.
struct PriceTestSuggestionCard: View {
    let suggestion: PriceTestSuggestion
    let onDismiss: () -> Void
    let onSetUp: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.xSmall) {
                Text(suggestion.title)
                    .atlasTextStyle(.headline)
                    .lineLimit(2)
                Spacer(minLength: Spacing.small)
                Image(systemName: "sparkle")
                    .imageScale(.small)
                    .foregroundStyle(Palette.ai)
                    .accessibilityHidden(true)
                Text("Suggested test", comment: "kind:label")
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.ai)
                    .lineLimit(1)
                SuggestionSourceTag(source: .assistant(client: suggestion.source))
                if let confidence = suggestion.layers?.confidence {
                    HowSureMeter(confidence: confidence)
                    Text(confidence.word)
                        .atlasTextStyle(.subheadline)
                        .foregroundStyle(Palette.label2)
                }
            }
            Text(suggestion.why)
                .atlasTextStyle(.callout)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("priceTest.suggestion.why")
            HStack(spacing: Spacing.small) {
                Text("\(suggestion.region.title) · \(suggestion.step.title) · 28 days", comment: "kind:label")
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(String(localized: "Dismiss", comment: "kind:button"), action: onDismiss)
                    .secondaryButton()
                    .accessibilityIdentifier("priceTest.suggestion.dismiss")
                Button(String(localized: "Set Up Test…", comment: "kind:button"), action: onSetUp)
                    .primaryButton()
                    .accessibilityIdentifier("priceTest.suggestion.setUp")
            }
            if let details = suggestion.layers?.details { SuggestionDetailsDisclosure(details: details) }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.aiSurface, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.banner, style: .continuous).strokeBorder(Palette.aiEdge, lineWidth: 0.5))
        .aiArrived(key: suggestion.id, arrivedAt: suggestion.receivedAt)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Suggested price test: \(suggestion.title)", comment: "kind:accessibility-label"))
        .accessibilityIdentifier("priceTest.suggestion")
    }
}
