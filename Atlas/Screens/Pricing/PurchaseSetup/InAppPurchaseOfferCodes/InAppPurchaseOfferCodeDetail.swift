//
//  InAppPurchaseOfferCodeDetail.swift
//  Atlas
//

import SwiftUI

/// One in-app purchase offer code App Store Connect has: who can redeem it,
/// its price, where it runs and how many codes it has, then its price in
/// the most-viewed territories it runs in beside the purchase's own.
struct InAppPurchaseOfferCodeDetail: View {
    let code: ExistingInAppPurchaseOfferCode
    let purchase: PricingProduct
    /// The purchase's territories, most-viewed first.
    let rows: [PricingRow]

    /// The table shows this many.
    private let shownCount = 9

    private var shownRows: [PricingRow] {
        let runs = Set(code.prices.territoryIDs)
        return Array(rows.filter { runs.contains($0.territory.id) }.prefix(shownCount))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                    Text(code.name)
                        .font(.title3.weight(.semibold))
                    Pill(text: code.isActive ? OfferKind.offerCode.title : String(localized: "Deactivated"))
                }
                facts
                if !shownRows.isEmpty { table }
            }
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .leavesChatRoom()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.iapOfferDetail")
    }

    private var facts: some View {
        box {
            fact(String(localized: "Who can redeem it"), InAppPurchaseOfferCodeEligibility.title(of: code.eligibilities), isFirst: true)
            fact(String(localized: "Offer price"), code.terms.summary(purchasePrice: purchase.basePrice))
            fact(String(localized: "Countries or regions"), code.prices.territoriesTitle)
            fact(String(localized: "Codes"), codesText)
        }
    }

    /// "1,500 on the App Store · 20 in the sandbox".
    private var codesText: String {
        var parts: [String] = []
        if let production = code.productionCodeCount { parts.append(String(localized: "\(production.formatted()) on the App Store")) }
        if let sandbox = code.sandboxCodeCount, sandbox > 0 { parts.append(String(localized: "\(sandbox.formatted()) in the sandbox")) }
        return parts.isEmpty ? code.codesSummary : parts.joined(separator: " · ")
    }

    private func fact(_ title: String, _ value: String, isFirst: Bool = false) -> some View {
        VStack(spacing: 0) {
            if !isFirst { Divider() }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.medium) {
                Text(title)
                Spacer(minLength: Spacing.medium)
                Text(value)
                    .foregroundStyle(Palette.label2)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, Spacing.medium)
            .frame(minHeight: 40)
            .accessibilityElement(children: .combine)
        }
    }

    private var table: some View {
        box {
            Grid(alignment: .trailing, horizontalSpacing: Spacing.medium, verticalSpacing: 0) {
                GridRow {
                    header(String(localized: "Territory")).gridColumnAlignment(.leading)
                    header(String(localized: "Purchase"))
                    header(String(localized: "Offer price"))
                }
                ForEach(shownRows) { row in
                    Divider()
                    tableRow(row)
                }
            }
            .padding(.horizontal, Spacing.medium)
            .monospacedDigit()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pricing.iapOffers.table")
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.callout.weight(.medium))
            .foregroundStyle(Palette.label2)
            .frame(minHeight: 30)
    }

    /// Modifiers go on the cells: a modified `GridRow` stops being a row.
    private func tableRow(_ row: PricingRow) -> some View {
        let currency = row.currency
        let offer = code.prices.customerPrices[row.territory.id]
        let offerText = offer.map { $0 == 0 ? String(localized: "Free") : currency.format($0) } ?? "—"
        return GridRow {
            HStack(spacing: Spacing.small) {
                FlagTile(regionCode: row.territory.alpha2)
                Text(row.territory.name).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "\(row.territory.name): purchase \(currency.format(row.shownPrice)), offer \(offerText)"))
            .accessibilityIdentifier("pricing.iapOffers.row.\(row.id)")
            Text(currency.format(row.shownPrice))
                .foregroundStyle(Palette.label2)
                .accessibilityHidden(true)
            Text(offerText)
                .fontWeight(.semibold)
                .accessibilityHidden(true)
        }
    }

    private func box(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Palette.separator, lineWidth: 0.5)
            }
    }
}
