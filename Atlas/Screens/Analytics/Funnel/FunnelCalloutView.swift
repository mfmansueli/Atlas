//
//  FunnelCalloutView.swift
//  Atlas
//

import SwiftUI

/// The funnel's one sentence, with up to two buttons: warning-tinted when
/// it names a loss, neutral otherwise.
struct FunnelCalloutView: View {
    let callout: FunnelCallout
    let onAction: (FunnelCalloutAction) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text(callout.title).font(.body.weight(.semibold))
                Text(callout.text)
                    .font(.callout)
                    .foregroundStyle(Palette.label2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Spacing.small)
            ForEach(callout.actions, id: \.self) { action in
                Button(action.title) { onAction(action) }
                    .controlSize(.regular)
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(callout.isLoss ? Palette.warnTint : Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analytics.funnel.callout")
    }
}
