//
//  BreakdownView.swift
//  Atlas
//

import SwiftUI

/// Break It Down: one table, switchable by territory, language, source,
/// device and product page, with the selected row in the inspector.
struct BreakdownView: View {
    @Bindable var viewModel: AnalyticsViewModel
    let table: BreakdownTable
    let onAct: (FindingAction, String) -> Void

    @State private var width: CGFloat = 0

    /// Under this the inspector narrows and the counts move into it.
    private static let compactWidth: CGFloat = 900
    /// Under this there's no room for both: the selected row's inspector
    /// takes the table's place until it's closed.
    private static let stackedWidth: CGFloat = 800

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack(spacing: Spacing.medium) {
                AnalyticsSegments(
                    label: String(localized: "Break down by"),
                    plain: BreakdownDimension.allCases.map { ($0, $0.title) },
                    selection: $viewModel.dimension,
                    identifier: "analytics.breakdown.dimension"
                )
                if table.subscribers != nil || table.afterDownload != nil {
                    AnalyticsSegments(
                        label: String(localized: "Columns"),
                        plain: BreakdownColumnGroup.allCases.map { ($0, $0.title) },
                        selection: $viewModel.columnGroup,
                        identifier: "analytics.breakdown.columns"
                    )
                }
                Spacer(minLength: 0)
                legend
            }
            HStack(alignment: .top, spacing: Spacing.medium) {
                if viewModel.selectedRow == nil || width >= Self.stackedWidth {
                    BreakdownTableView(viewModel: viewModel, table: table, layout: layout)
                }
                if let row = viewModel.selectedRow {
                    BreakdownInspector(
                        row: row, table: table, context: viewModel.context, width: inspectorWidth
                    ) {
                        viewModel.selectedRowID = nil
                    } onAct: { action, origin in
                        onAct(action, origin)
                    }
                }
            }
            .padding(.bottom, Spacing.medium)
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
        // A container of its own: otherwise its identifier replaces the table's and the inspector's.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analytics.breakdown")
    }

    private var inspectorWidth: CGFloat? {
        if width < Self.stackedWidth { return nil }
        return width < Self.compactWidth ? 250 : Metrics.inspectorWidth
    }

    private var layout: BreakdownColumnLayout {
        BreakdownColumnLayout(
            isCompact: viewModel.selectedRow != nil || width < Self.compactWidth, hasSales: table.dimension.hasSales,
            group: table.subscribers != nil || table.afterDownload != nil ? viewModel.columnGroup : .funnel
        )
    }

    /// What the marks mean, once, above the table.
    @ViewBuilder
    private var legend: some View {
        if width >= Self.compactWidth {
            HStack(spacing: Spacing.xSmall) {
                Text("Against the app’s average:")
                Image(systemName: RateStanding.better.systemImage).font(.footnote)
                Text("better")
                Image(systemName: RateStanding.worse.systemImage).font(.footnote).foregroundStyle(Palette.warn)
                Text("worse")
                Image(systemName: RateStanding.same.systemImage).font(.footnote)
                Text("about the same ·")
                ConfidenceMeter(bars: 2)
                Text("how sure · “3 of 40” too few to tell")
            }
            .font(.subheadline)
            .foregroundStyle(Palette.label2)
            .lineLimit(1)
            .accessibilityElement(children: .combine)
        }
    }
}
