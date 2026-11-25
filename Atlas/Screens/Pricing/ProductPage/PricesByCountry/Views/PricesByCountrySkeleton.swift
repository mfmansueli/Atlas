//
//  PricesByCountrySkeleton.swift
//  Atlas
//

import SwiftUI

/// Grey rows under the table's column titles while the product's prices
/// load: a flag, a name and region, a price, US dollars, how it's set.
struct PricesByCountrySkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.medium) {
                ForEach(PricesByCountryTable.columnTitles, id: \.self) { title in
                    Text(title)
                        .atlasTextStyle(.callout)
                        .foregroundStyle(Palette.label2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, Spacing.small)
            .frame(height: Metrics.tableHeaderHeight)
            .overlay(alignment: .bottom) { Divider() }
            ForEach(0..<12, id: \.self) { _ in
                HStack(spacing: Spacing.medium) {
                    HStack(spacing: Spacing.xSmall) {
                        SkeletonBlock(width: 18, height: 12)
                        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                            SkeletonBlock(width: 110)
                            SkeletonBlock(width: 64, height: 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    SkeletonBlock(width: 80, height: 14).frame(maxWidth: .infinity, alignment: .leading)
                    SkeletonBlock(width: 44).frame(maxWidth: .infinity, alignment: .leading)
                    SkeletonBlock(width: 70).frame(maxWidth: .infinity, alignment: .leading)
                    SkeletonBlock(width: 90).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, Spacing.small)
                .frame(height: Metrics.tableRowHeight + Spacing.medium)
            }
        }
        .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Reading prices from Apple", comment: "kind:loading"))
        .accessibilityIdentifier("countries.skeleton")
    }
}
