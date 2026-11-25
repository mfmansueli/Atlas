//
//  BreakdownTableView.swift
//  Atlas
//

import SwiftUI

/// The breakdown as a ranked table: a sortable header, the app's totals,
/// then one row per territory, language, source, device or page.
struct BreakdownTableView: View {
    @Bindable var viewModel: AnalyticsViewModel
    let table: BreakdownTable
    let layout: BreakdownColumnLayout

    /// Nil in previews without the main window.
    @Environment(WorkspaceNavigator.self) private var navigator: WorkspaceNavigator?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            totals
            Divider()
            ScrollView {
                if viewModel.sortedRows.isEmpty {
                    Text(table.dimension.emptyText)
                        .font(.callout)
                        .foregroundStyle(Palette.label2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.medium)
                        .accessibilityIdentifier("analytics.breakdown.empty")
                }
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.sortedRows) { row in
                        BreakdownRowView(
                            row: row, layout: layout, table: table, isSelected: viewModel.selectedRowID == row.id,
                            onOpenPage: openPage(row)
                        ) {
                            viewModel.selectedRowID = viewModel.selectedRowID == row.id ? nil : row.id
                        }
                        Divider()
                    }
                }
            }
            Text(table.footer)
                .font(.subheadline)
                .foregroundStyle(Palette.label2)
                // Not fixedSize: outside a scroll view that's measured near
                // zero wide and grows the window's minimum height.
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.medium)
                .padding(.vertical, Spacing.small)
                .accessibilityIdentifier("analytics.breakdown.footer")
        }
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Palette.separator, lineWidth: 0.5) }
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analytics.breakdown.table")
    }

    /// A custom product page's row opens the page in Custom Product Pages.
    private func openPage(_ row: BreakdownRow) -> (() -> Void)? {
        guard table.dimension == .productPage, row.name != ProductPageNumbers.defaultPageName, let navigator else { return nil }
        let appID = viewModel.app.id
        return { navigator.open(.productPages, intent: .showProductPage(name: row.name), appID: appID) }
    }

    private var header: some View {
        HStack(spacing: 0) {
            headerButton(.name, title: table.dimension.title)
                .frame(minWidth: BreakdownColumnLayout.nameMinimum, maxWidth: .infinity, alignment: .leading)
            ForEach(layout.columns) { column in
                headerButton(column, title: column.title)
                    .frame(width: layout.width(of: column), alignment: .trailing)
            }
        }
        .padding(.horizontal, Spacing.medium)
        .frame(height: Metrics.tableHeaderHeight)
        .background(Palette.fill1)
    }

    private func headerButton(_ column: BreakdownColumn, title: String) -> some View {
        let isSorted = viewModel.sortColumn == column
        return Button {
            viewModel.sort(by: column)
        } label: {
            HStack(spacing: 2) {
                Text(title)
                if isSorted {
                    Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down").imageScale(.small)
                }
            }
            .font(.subheadline.weight(isSorted ? .semibold : .medium))
            .foregroundStyle(isSorted ? Palette.label : Palette.label2)
            .lineLimit(1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isSorted ? String(localized: "\(title), sorted") : String(localized: "Sort by \(title)")))
        .accessibilityIdentifier("analytics.breakdown.sort.\(column.rawValue)")
    }

    private var totals: some View {
        HStack(spacing: 0) {
            Text("All of \(viewModel.dataset.appName)")
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .frame(minWidth: BreakdownColumnLayout.nameMinimum, maxWidth: .infinity, alignment: .leading)
            ForEach(layout.columns) { column in
                Text(Self.text(column, totals: table.totals, subscribers: table.subscribers, after: table.afterDownload))
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(width: layout.width(of: column), alignment: .trailing)
            }
        }
        .padding(.horizontal, Spacing.medium)
        .frame(height: 30)
        .accessibilityElement(children: .combine)
    }

    /// A cell's text, the funnel's or the newer reports'.
    static func text(_ column: BreakdownColumn, totals: FunnelTotals, subscribers: SubscriberCounts?, after: AfterDownloadNumbers?) -> String {
        switch column {
        case .trials: subscribers.map { AnalyticsText.count($0.trials) } ?? "—"
        case .paid: subscribers.map { AnalyticsText.count($0.paid) } ?? "—"
        case .trialToPaid: subscribers?.trialToPaidFraction.map(AnalyticsText.percent) ?? "—"
        case .deleted30: after?.deletedWithin30.fraction.map(AnalyticsText.percent) ?? "—"
        case .sessionsPerWeek: after?.sessionsPerWeek.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—"
        default: totalText(column, totals)
        }
    }

    static func totalText(_ column: BreakdownColumn, _ totals: FunnelTotals) -> String {
        switch column {
        case .name: ""
        case .impressions: totals.impressions.map(AnalyticsText.count) ?? "—"
        case .pageViews: totals.pageViews.map(AnalyticsText.count) ?? "—"
        case .viewRate: totals.fraction(.pageViews).map(AnalyticsText.percent) ?? "—"
        case .downloads: totals.downloads.map(AnalyticsText.count) ?? "—"
        case .downloadRate: totals.fraction(.downloads).map(AnalyticsText.percent) ?? "—"
        case .starts: totals.starts.map(AnalyticsText.count) ?? "—"
        case .startRate: totals.startFraction.map(AnalyticsText.percent) ?? "—"
        case .proceeds: totals.proceeds.map(AnalyticsText.dollars) ?? "—"
        case .trials, .paid, .trialToPaid, .deleted30, .sessionsPerWeek: "—"
        }
    }
}
