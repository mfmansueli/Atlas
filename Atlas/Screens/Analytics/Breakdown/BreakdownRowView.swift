//
//  BreakdownRowView.swift
//  Atlas
//

import SwiftUI

/// One row of the breakdown table. Selecting it opens the inspector.
struct BreakdownRowView: View {
    let row: BreakdownRow
    let layout: BreakdownColumnLayout
    let table: BreakdownTable
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 0) {
                HStack(spacing: Spacing.small) {
                    if let region = row.regionCode { FlagTile(regionCode: region) }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(row.name).font(.callout).lineLimit(1)
                        if let detail = row.detail {
                            Text(detail).font(.caption).foregroundStyle(Palette.label3).lineLimit(1)
                        }
                    }
                }
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
        BreakdownTableView.totalText(column, row.totals)
    }

    private var accessibilityValue: String {
        layout.columns.map { column in
            let value = row.rate(column)?.text ?? text(column)
            return "\(column.title) \(value)"
        }
        .joined(separator: ", ")
    }
}
