//
//  BreakdownView.swift
//  Atlas
//

import SwiftUI

/// Break It Down (board 92): one table, split by country, language,
/// source, device or product page (referrers and campaigns in More), with
/// the selected row in the inspector. From `Metrics.breakdownCompactWidth`
/// up the inspector sits beside the table; under it the counts hide and
/// the inspector slides over the table from the right.
struct BreakdownView: View {
    @Bindable var viewModel: AnalyticsViewModel
    let table: BreakdownTable
    let onAct: (FindingAction, String) -> Void

    @State private var width: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            controls
            if let explanation = viewModel.proceedsBannerText {
                BreakdownProceedsBanner(explanation: explanation) {
                    viewModel.closeProceedsBanner()
                }
            }
            content
                .padding(.bottom, Spacing.medium)
                .leavesChatRoom(.bottomEdge)
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { width = $0 }
        // A container of its own: otherwise its identifier replaces the table's and the inspector's.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analytics.breakdown")
    }

    private var controls: some View {
        HStack(spacing: Spacing.medium) {
            Picker(String(localized: "Break down by", comment: "kind:label · Break It Down"), selection: dimension) {
                ForEach(BreakdownDimension.segmented) { dimension in
                    Text(dimension.segmentTitle).tag(BreakdownDimension?.some(dimension))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .accessibilityIdentifier("analytics.breakdown.dimension")
            moreMenu
            if table.subscribers != nil || table.afterDownload != nil {
                Picker(String(localized: "Columns", comment: "kind:label · Break It Down"), selection: $viewModel.columnGroup) {
                    ForEach(BreakdownColumnGroup.allCases, id: \.self) { group in
                        Text(group.title).tag(group)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("analytics.breakdown.columns")
            }
            Spacer(minLength: 0)
        }
    }

    /// Referrer and Campaign, from Apple's detailed reports: a menu beside
    /// the five splits, named after the one shown when it's one of them.
    private var moreMenu: some View {
        Menu {
            ForEach(BreakdownDimension.more) { dimension in
                Button(dimension.title) { viewModel.choose(dimension) }
            }
        } label: {
            Text(viewModel.dimension.isSegmented ? String(localized: "More", comment: "kind:button · Break It Down splits") : viewModel.dimension.title)
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(Text("Referrers and campaign links, from Apple’s detailed reports.", comment: "kind:tooltip · Break It Down"))
        .accessibilityIdentifier("analytics.breakdown.more")
    }

    /// The segmented control's selection: a split in More selects none.
    private var dimension: Binding<BreakdownDimension?> {
        Binding(
            get: { viewModel.dimension.isSegmented ? viewModel.dimension : nil },
            set: { if let value = $0 { viewModel.choose(value) } }
        )
    }

    @ViewBuilder
    private var content: some View {
        let overlays = BreakdownColumnLayout.inspectorOverlays(width: width)
        if overlays {
            BreakdownTableView(viewModel: viewModel, table: table, layout: layout)
                .overlay(alignment: .topTrailing) {
                    if let row = viewModel.selectedRow {
                        inspector(row)
                            .depth(.popover)
                            .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .clipped()
                .animation(reduceMotion ? MotionTiming.fast.animation : MotionTiming.layout.animation, value: viewModel.selectedRowID)
        } else {
            HStack(alignment: .top, spacing: Spacing.medium) {
                BreakdownTableView(viewModel: viewModel, table: table, layout: layout)
                if let row = viewModel.selectedRow {
                    inspector(row)
                }
            }
        }
    }

    private func inspector(_ row: BreakdownRow) -> some View {
        BreakdownInspector(row: row, table: table, context: viewModel.context, width: Metrics.inspectorWidth, dataset: viewModel.dataset) {
            viewModel.selectedRowID = nil
        } onAct: { action, origin in
            onAct(action, origin)
        }
    }

    private var layout: BreakdownColumnLayout {
        BreakdownColumnLayout.make(
            width: width,
            hasInspector: viewModel.selectedRow != nil,
            hasSales: table.dimension.hasSales,
            group: table.subscribers != nil || table.afterDownload != nil ? viewModel.columnGroup : .funnel,
            highlighted: viewModel.highlightedColumn
        )
    }
}
