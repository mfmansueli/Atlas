//
//  CountryPricePointList.swift
//  Atlas
//

import SwiftUI

/// The popover's list of App Store Connect price points for one country,
/// each with its US dollars, the suggested and today's marked, the picked
/// one checked. A grey skeleton while Apple's points load.
struct CountryPricePointList: View {
    let row: CountryPriceRow
    let points: [PricePoint]
    let isLoading: Bool
    @Binding var selection: Decimal

    var body: some View {
        Group {
            if isLoading {
                skeleton
            } else {
                list
            }
        }
        .background(Palette.fill1, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Apple’s price points", comment: "kind:label"))
        .accessibilityIdentifier("countries.popover.points")
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(points, id: \.customerPrice) { point in
                        pointRow(point)
                            .id(point.customerPrice)
                    }
                }
                .padding(Spacing.xxSmall)
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
        }
    }

    private func pointRow(_ point: PricePoint) -> some View {
        let isSelected = !PricingRow.differs(point.customerPrice, selection)
        let isSuggested = row.suggestion.map { !PricingRow.differs($0.customerPrice, point.customerPrice) } ?? false
        let isNow = !PricingRow.differs(point.customerPrice, row.current.customerPrice)
        let price = row.currency.format(point.customerPrice)
        let dollars = CountryPriceRow.dollarsText(row.dollars(point.customerPrice))
        return Button {
            selection = point.customerPrice
        } label: {
            HStack(spacing: Spacing.xSmall) {
                Image(systemName: "checkmark")
                    .imageScale(.small)
                    .foregroundStyle(Palette.accent)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
                Text(price)
                    .monospacedDigit()
                if isSuggested {
                    Pill(text: String(localized: "Suggested", comment: "kind:pill"), style: .machineTranslated)
                        .fixedSize()
                }
                if isNow {
                    Text("Now", comment: "kind:label")
                        .atlasTextStyle(.subheadline)
                        .foregroundStyle(Palette.label3)
                }
                Spacer(minLength: Spacing.small)
                Text(dollars)
                    .atlasTextStyle(.subheadline)
                    .foregroundStyle(Palette.label2)
                    .monospacedDigit()
            }
            .atlasTextStyle(.callout)
            .padding(.horizontal, Spacing.small)
            .frame(minHeight: Metrics.tableRowHeight)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: Radius.menuRow, style: .continuous).fill(Palette.accentTint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityText(price: price, dollars: dollars, isSuggested: isSuggested, isNow: isNow)))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("countries.popover.point.\(NSDecimalNumber(decimal: point.customerPrice).stringValue)")
    }

    private func accessibilityText(price: String, dollars: String, isSuggested: Bool, isNow: Bool) -> String {
        var parts = [price, dollars]
        if isSuggested { parts.append(String(localized: "suggested", comment: "kind:label")) }
        if isNow { parts.append(String(localized: "today’s price", comment: "kind:label")) }
        return parts.joined(separator: ", ")
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<6, id: \.self) { _ in
                HStack {
                    SkeletonBlock(width: 90)
                    Spacer()
                    SkeletonBlock(width: 44)
                }
                .padding(.horizontal, Spacing.small)
                .frame(height: Metrics.tableRowHeight)
            }
        }
        .padding(Spacing.xxSmall)
        .frame(maxHeight: .infinity, alignment: .top)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Reading Apple’s price points", comment: "kind:loading"))
    }
}
