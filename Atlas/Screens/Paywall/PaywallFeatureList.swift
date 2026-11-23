//
//  PaywallFeatureList.swift
//  Atlas
//

import SwiftUI

/// The paywall's left side: what Pro adds, with the feature the person
/// clicked highlighted.
struct PaywallFeatureList: View {
    let highlighted: ProFeature?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            HStack(spacing: Spacing.medium) {
                Image(systemName: "sparkles")
                    .font(.title.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Atlas Pro")
                        .font(.title2.weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("paywall.title")
                    Text("Free does it one at a time. Pro does it all at once.")
                        .font(.body)
                        .opacity(0.82)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, Spacing.small)
            ForEach(ProFeature.allCases) { feature in
                row(feature)
            }
            Spacer(minLength: Spacing.small)
            Text("AI runs on your own assistant or API key, so Pro’s price never includes AI usage.")
                .font(.callout)
                .opacity(0.78)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.xxSmall)
        }
        .foregroundStyle(.white)
        .padding(.init(top: 26, leading: 20, bottom: 22, trailing: 20))
        .frame(width: PaywallStyle.paneWidth, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(PaywallStyle.paneGradient)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("paywall.features")
    }

    private func row(_ feature: ProFeature) -> some View {
        let isOn = feature == highlighted
        return HStack(alignment: .top, spacing: Spacing.small + 2) {
            Image(systemName: feature.systemImage)
                .font(.body.weight(.medium))
                .frame(width: 26, height: 26)
                .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(feature.title)
                    .font(.body.weight(.semibold))
                Text(feature.detail)
                    .font(.callout)
                    .opacity(0.78)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Spacing.small)
        .padding(.vertical, Spacing.xSmall)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(isOn ? 0.16 : 0), in: RoundedRectangle(cornerRadius: Radius.banner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.banner, style: .continuous).strokeBorder(.white.opacity(isOn ? 0.4 : 0), lineWidth: 0.5))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier("paywall.feature.\(feature.rawValue)")
    }
}

#Preview {
    PaywallFeatureList(highlighted: .autopilot).frame(height: 600)
}
