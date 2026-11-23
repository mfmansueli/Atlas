//
//  ProductPagesTable.swift
//  Atlas
//

import SwiftUI

/// The pages as a table: the default page first, as the reference for
/// every rate, then each page. Wide, one line a page in columns; under 900
/// points, two lines a page, so nothing is cut.
struct ProductPagesTable: View {
    @Bindable var viewModel: ProductPagesViewModel
    let isCompact: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !isCompact {
                header
                Divider()
            }
            ProductPageDefaultRow(viewModel: viewModel, isCompact: isCompact)
            ForEach(viewModel.listedPages) { page in
                Divider()
                ProductPageRow(viewModel: viewModel, page: page, isCompact: isCompact)
            }
            Divider()
            Text(footer)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)
                .accessibilityIdentifier("pages.footer")
        }
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pages.table")
    }

    private var header: some View {
        HStack(spacing: Spacing.medium) {
            Text("Page").frame(minWidth: ProductPageRow.nameMinimum, maxWidth: .infinity, alignment: .leading)
            Text("Status").frame(width: ProductPageRow.statusWidth, alignment: .leading)
            Text("Impressions → views → downloads").frame(width: ProductPageRow.funnelWidth, alignment: .leading)
            Text("Download rate").frame(width: ProductPageRow.rateWidth, alignment: .leading)
            if viewModel.hasSubscriberNumbers {
                Text("Paid subscribers").frame(width: ProductPageRow.subscribersWidth, alignment: .leading)
                Text("Trial → paid").frame(width: ProductPageRow.trialToPaidWidth, alignment: .leading)
            }
            Color.clear.frame(width: ProductPageRow.copyWidth, height: 1)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Palette.label2)
        .lineLimit(1)
        .padding(.horizontal, Spacing.medium)
        .frame(height: Metrics.tableHeaderHeight)
        .background(Palette.fill1)
        .accessibilityHidden(true)
    }

    private var footer: String {
        let rate = String(localized: "Download rate is downloads out of page views.")
        guard let through = viewModel.numbersThrough else {
            return String(localized: "Numbers come from Analytics once its reports arrive. \(rate)")
        }
        let day = through.formatted(.dateTime.month(.abbreviated).day())
        return String(localized: """
        Last 28 days, through \(day), as in Analytics → Break It Down → Product Page. \(rate)
        """)
    }
}
