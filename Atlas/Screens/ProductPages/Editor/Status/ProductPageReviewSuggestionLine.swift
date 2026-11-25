//
//  ProductPageReviewSuggestionLine.swift
//  Atlas
//

import SwiftUI

/// An assistant's suggestion for the page and App Review, above its status:
/// who suggests what, why, and Dismiss. The page's own button (Submit for
/// Review…, Cancel Submission or Edit…) does it.
struct ProductPageReviewSuggestionLine: View {
    let suggestion: ProductPageReviewSuggestion
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            Image(systemName: "sparkle")
                .imageScale(.small)
                .foregroundStyle(Palette.ai)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xSmall) {
                    Text(title)
                        .font(.callout.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if let confidence = suggestion.layers?.confidence { HowSureMeter(confidence: confidence) }
                }
                Text(suggestion.why)
                    .font(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pages.reviewSuggestion.why")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(String(localized: "Dismiss", comment: "kind:button"), action: onDismiss)
                .controlSize(.regular)
                .accessibilityIdentifier("pages.reviewSuggestion.dismiss")
        }
        .padding(Spacing.small)
        .background(Palette.aiSurface, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .aiArrived(key: suggestion.id.uuidString, arrivedAt: suggestion.receivedAt)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
        .accessibilityIdentifier("pages.reviewSuggestion")
    }

    /// "Claude Code suggests submitting this page. Use Submit for Review…."
    private var title: String {
        let button = suggestion.action.buttonTitle
        return switch suggestion.action {
        case .submit:
            String(localized: "\(suggestion.client) suggests submitting this page to App Review. Use \(button)", comment: "kind:label")
        case .cancelSubmission:
            String(localized: "\(suggestion.client) suggests taking this page back from App Review. Use \(button).", comment: "kind:label")
        case .newVersion:
            String(localized: "\(suggestion.client) suggests a new version of this page. Use \(button)", comment: "kind:label")
        }
    }
}
