//
//  FunnelStepTile.swift
//  Atlas
//

import SwiftUI

/// One step's count, its change against the previous period, or why it
/// has no number (the fix is offered on the line under the funnel).
struct FunnelStepTile: View {
    let step: FunnelStep

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(step.stage.title)
                .font(.caption)
                .foregroundStyle(Palette.label2)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(step.countText)
                .font(.system(size: 19, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(step.gap == nil ? Palette.label : Palette.label3)
            if let gap = step.gap {
                Text(gap.text)
                    .font(.caption)
                    .foregroundStyle(Palette.warning)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let change = step.change {
                Text("\(change) vs before")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.label2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 74, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Radius.banner, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5) }
        .help(step.stage.hint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(step.accessibilityText))
        .accessibilityIdentifier("analytics.funnel.step.\(step.stage.rawValue)")
    }
}
