//
//  PricingOffersSkeleton.swift
//  Atlas
//

import SwiftUI

/// Grey rows shaped like the Offers tab (the list of offers, then the
/// selected one's details) while a product's offers are read.
struct PricingOffersSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                ForEach(0..<4, id: \.self) { index in
                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        SkeletonBlock(width: index.isMultiple(of: 2) ? 150 : 120, height: 12)
                        SkeletonBlock(width: 96, height: 8)
                    }
                }
            }
            .padding(Spacing.medium)
            .frame(width: 250, alignment: .leading)
            Divider()
            VStack(alignment: .leading, spacing: Spacing.medium) {
                SkeletonBlock(width: 180, height: 14)
                ForEach(0..<6, id: \.self) { _ in
                    HStack(spacing: Spacing.medium) {
                        SkeletonBlock(width: 120)
                        Spacer(minLength: Spacing.medium)
                        SkeletonBlock(width: 64)
                    }
                }
            }
            .padding(Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(localized: "Reading offers from App Store Connect", comment: "kind:accessibility-label")))
        .accessibilityIdentifier("pricing.offers.skeleton")
    }
}

#Preview {
    PricingOffersSkeleton()
        .frame(width: 640, height: 360)
}
