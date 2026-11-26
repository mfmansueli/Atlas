//
//  AnalyticsKPICard.swift
//  Atlas
//

import SwiftUI

/// One of the Overview's four numbers (board 92): its name, the number,
/// the line under it, and the blue line saying where it goes. The whole
/// card is the button.
struct AnalyticsKPICard: View {
    let number: AnalyticsKPI
    let onOpen: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Group {
            if number.link != nil {
                Button(action: onOpen) { card }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(.isButton)
            } else {
                card
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(number.accessibilityText))
        .accessibilityIdentifier("analytics.kpi.\(number.kind.rawValue)")
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Spacing.tiny) {
            Text(number.title)
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.label2)
                .lineLimit(1)
            if number.isLoading {
                SkeletonLine(fraction: 0.5, height: Metrics.skeletonTitleLine)
                    .padding(.vertical, Spacing.xxSmall)
                SkeletonLine(fraction: 0.8)
            } else {
                Text(number.value)
                    .atlasTextStyle(.title2)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let detail = number.detail {
                    Text(detail)
                        .atlasTextStyle(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(number.tone.color)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            if let link = number.link {
                HStack(spacing: Spacing.tiny) {
                    Text(link)
                    Image(systemName: "chevron.right").imageScale(.small)
                }
                .atlasTextStyle(.subheadline)
                .foregroundStyle(Palette.accentText)
                .lineLimit(1)
                .padding(.top, Spacing.tiny)
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.raised, in: shape)
        .overlay {
            shape.strokeBorder(contrast == .increased ? Palette.separator2 : Palette.separator, lineWidth: contrast == .increased ? 1 : 0.5)
        }
        .contentShape(shape)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
    }
}
