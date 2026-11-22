//
//  BreakdownRowView.swift
//  Atlas
//

import SwiftUI

/// One row of the breakdown table. Selecting it opens the inspector. A
/// custom product page's row has Open Page, which opens it in Custom
/// Product Pages.
struct BreakdownRowView: View {
    let row: BreakdownRow
    let layout: BreakdownColumnLayout
    let table: BreakdownTable
    let isSelected: Bool
    var onOpenPage: (() -> Void)?
    let onSelect: () -> Void

    /// The room Open Page takes at the end of the name column.
    private static let openPageWidth: CGFloat = 92

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 0) {
                HStack(spacing: Spacing.small) {
                    if let region = row.regionCode { FlagTile(regionCode: region) }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(row.name).font(.callout).lineLimit(1)
                        if let detail = row.detail {
                            Text(detail).font(.caption).foregroundStyle(Palette.label2).lineLimit(1)
                        }
                    }
                }
                .padding(.trailing, onOpenPage == nil ? 0 : Self.openPageWidth)
                .frame(minWidth: BreakdownColumnLayout.nameMinimum, maxWidth: .infinity, alignment: .leading)
                ForEach(layout.columns) { column in
                    cell(column).frame(width: layout.width(of: column), alignment: .trailing)
                }
            }
            .padding(.horizontal, Spacing.medium)
            .frame(minHeight: row.detail == nil ? 30 : 38)
            .background(isSelected ? Palette.accentTint : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(row.name))
        .accessibilityValue(Text(accessibilityValue))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("analytics.breakdown.row.\(row.id)")
        // Beside the row's button, not in it: a button can't hold another.
        .overlay(alignment: .trailing) {
            if let onOpenPage {
                Button("Open Page", action: onOpenPage)
                    .controlSize(.small)
                    .help(Text("Open in Custom Product Pages"))
                    .accessibilityLabel(Text("Open this product page"))
                    .accessibilityIdentifier("analytics.breakdown.openPage.\(row.id)")
                    .padding(.trailing, Spacing.medium + Spacing.small + layout.columns.reduce(0) { $0 + layout.width(of: $1) })
            }
        }
    }

    @ViewBuilder
    private func cell(_ column: BreakdownColumn) -> some View {
        if let rate = row.rate(column) {
            RateLabel(rate: rate, detail: rate.detail(averageName: String(localized: "The app"), average: average(column)))
        } else {
            Text(text(column))
                .font(.callout)
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(text(column) == "—" ? Palette.label3 : Palette.label)
        }
    }

    private func average(_ column: BreakdownColumn) -> Double? {
        switch column {
        case .viewRate: table.totals.fraction(.pageViews)
        case .downloadRate: table.totals.fraction(.downloads)
        case .startRate: table.totals.startFraction
        default: nil
        }
    }

    private func text(_ column: BreakdownColumn) -> String {
        BreakdownTableView.text(column, totals: row.totals, subscribers: row.subscribers, after: row.afterDownload)
    }

    private var accessibilityValue: String {
        layout.columns.map { column in
            let value = row.rate(column)?.text ?? text(column)
            return "\(column.title) \(value)"
        }
        .joined(separator: ", ")
    }
}
