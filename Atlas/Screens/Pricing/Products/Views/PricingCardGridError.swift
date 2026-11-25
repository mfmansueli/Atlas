//
//  PricingCardGridError.swift
//  Atlas
//

import SwiftUI

/// A product card's Apple price points that didn't load (board 76): the
/// error template, what happened · what to do, in amber since today's
/// prices still show and only the suggestion waits, with Try Again right
/// there, which reads that product's points again. Apple's own text is in
/// the help, never the message.
struct PricingCardGridError: View {
    let copy: AppleErrorCopy
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
            InlineMessage.warning(copy.summary)
                .help(copy.details.map { Text(verbatim: $0) } ?? Text(verbatim: copy.summary))
                .accessibilityIdentifier("pricing.card.gridFailure")
            Spacer(minLength: Spacing.small)
            Button(String(localized: "Try Again", comment: "kind:button"), action: onRetry)
                .secondaryButton()
                .accessibilityIdentifier("pricing.card.gridRetry")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.card.gridError")
    }
}
