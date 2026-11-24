//
//  ReportsFromAppleSheet.swift
//  Atlas
//

import SwiftUI

/// Reports from Apple: every report Analytics reads for the app, what it
/// adds, and where it stands (ready through a day, sent empty, or asked).
struct ReportsFromAppleSheet: View {
    @Bindable var viewModel: AnalyticsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Reports from Apple").font(.title2.weight(.semibold))
            Text("Made daily for \(viewModel.app.name). “A sample” counts only people who share analytics.")
                .foregroundStyle(Palette.label2)
                .lineLimit(3)
            AnalyticsBox {
                AnalyticsColumns(titles: [String(localized: "Report"), String(localized: "Status")], widths: [240])
                ForEach(rows, id: \.title) { row in
                    Divider()
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.small) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title).font(.callout.weight(.medium))
                            Text(row.adds).font(.subheadline).foregroundStyle(Palette.label2).lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.status)
                            .font(.callout)
                            .foregroundStyle(row.isReady ? Palette.label : Palette.label2)
                            .frame(width: 240, alignment: .trailing)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, Spacing.xSmall)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("analytics.reports.row.\(row.id)")
                }
            }
            if let error = viewModel.store.reportsError {
                InlineMessage.warning(error)
            }
            HStack {
                if viewModel.activity.isLoading {
                    ProgressView().controlSize(.small)
                    Text("Checking…").font(.subheadline).foregroundStyle(Palette.label2)
                }
                Spacer()
                Button("Check Now") { Task { await viewModel.refresh(force: true) } }
                    .disabled(viewModel.activity.isLoading)
                    .accessibilityIdentifier("analytics.reports.checkNow")
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Spacing.xLarge)
        .frame(width: 640)
        .accessibilityIdentifier("analytics.reports")
    }

    private struct Row {
        var id: String
        var title: String
        var adds: String
        var status: String
        var isReady: Bool
    }

    private var rows: [Row] {
        let through = viewModel.dataset.through
        var rows = [
            Row(
                id: "engagement", title: String(localized: "App Store Discovery and Engagement", comment: "kind:sheet-title"),
                adds: String(localized: "Impressions and page views, by source, page and territory"),
                status: through.map { String(localized: "Ready · through \(AnalyticsText.day($0.date))") } ?? String(localized: "Asked"), isReady: through != nil
            ),
        ]
        let asked = viewModel.reports.firstChecked ?? viewModel.askedOn
        for kind in AppleReportKind.allCases {
            let progress = viewModel.reports.progress(kind)
            let status: String
            let ready: Bool
            switch progress.state {
            case let .ready(last):
                status = String(localized: "Ready · through \(AnalyticsText.day(last.date))") + (kind.isSample ? String(localized: " · a sample") : "")
                ready = true
            case .noRows:
                status = String(localized: "Apple sent this report empty")
                ready = false
            case .asked:
                status = asked.map { String(localized: "Asked \(AnalyticsText.day($0)) — expected by \(AnalyticsText.day($0.addingTimeInterval(2 * 86400)))") }
                    ?? String(localized: "Not asked yet")
                ready = false
            }
            rows.append(Row(id: kind.rawValue, title: kind.title, adds: kind.adds, status: status, isReady: ready))
        }
        return rows
    }
}
