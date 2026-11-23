//
//  AnalyticsScreen.swift
//  Atlas
//

import SwiftUI

/// The Analytics section: its header over the setup state, the first
/// download, or the five views.
struct AnalyticsScreen: View {
    @Bindable var viewModel: AnalyticsViewModel
    /// Changes of a finding's area waiting in Review & Push.
    var waitingCount: (AnalyticsFinding) -> Int = { _ in 0 }
    /// Follows an action to its section, with what the bar there says.
    var onAct: (FindingAction, String) -> Void = { _, _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            content
        }
        .padding(.horizontal, Spacing.xLarge)
        .padding(.top, Spacing.small)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.content)
        .sheet(isPresented: $viewModel.isReportsPresented) {
            ReportsFromAppleSheet(viewModel: viewModel)
        }
    }

    private var header: some View {
        SectionHeader(
            subtitle: String(localized: "Where people drop off between seeing \(viewModel.app.name) and paying, and what to change next.")
        ) {
            if viewModel.setup == .ready, viewModel.funnel != nil {
                if viewModel.funnel?.isNew == true {
                    Pill(text: String(localized: "\(viewModel.dataset.dayCount) days"), isProminent: true)
                } else {
                    AnalyticsSegments(
                        label: String(localized: "Period"),
                        plain: [7, 28, 90].map { ($0, String(localized: "\($0) days")) },
                        selection: $viewModel.days,
                        identifier: "analytics.period"
                    )
                }
            }
            Button {
                viewModel.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Analytics settings")
            .accessibilityLabel(Text("Analytics settings"))
            .accessibilityIdentifier("analytics.settingsButton")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.setup {
        case .off:
            centered {
                AnalyticsOffView(
                    appName: viewModel.app.name,
                    hasVendorNumber: !viewModel.store.settings.vendorNumber.isEmpty,
                    isAsking: viewModel.activity.isLoading,
                    errorMessage: failure
                ) {
                    Task { await viewModel.ask() }
                } onAddVendorNumber: {
                    viewModel.openSettings(focus: .vendorNumber)
                }
            }
        case let .waiting(asked):
            if case let .loading(finished) = viewModel.activity {
                AnalyticsLoadingView(appName: viewModel.app.name, finished: finished)
            } else {
                centered {
                    AnalyticsWaitingView(
                        asked: asked, lastChecked: viewModel.lastChecked, now: viewModel.store.now(),
                        isChecking: viewModel.activity.isLoading, errorMessage: failure
                    ) {
                        Task { await viewModel.refresh(force: true) }
                    }
                }
            }
        case .keyCannotAsk:
            centered {
                AnalyticsKeyCannotAskView(keyID: viewModel.keyID) {
                    Task { await viewModel.ask() }
                }
            }
        case .ready:
            if let funnel = viewModel.funnel {
                ready(funnel)
            } else if case let .loading(finished) = viewModel.activity {
                AnalyticsLoadingView(appName: viewModel.app.name, finished: finished)
            } else {
                centered {
                    ContentUnavailableView {
                        Label("No numbers yet", systemImage: "chart.bar")
                    } description: {
                        Text(failure ?? String(localized: "Apple’s reports arrived without any days for \(viewModel.app.name)."))
                    } actions: {
                        Button("Check Again") { Task { await viewModel.refresh(force: true) } }
                    }
                }
            }
        }
    }

    private var failure: String? {
        if case let .failed(message) = viewModel.activity { return message }
        return nil
    }

    private func centered(@ViewBuilder _ content: () -> some View) -> some View {
        ScrollView {
            content()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xLarge)
        }
    }

    @ViewBuilder
    private func ready(_ funnel: FunnelReport) -> some View {
        AnalyticsReadyBar(viewModel: viewModel, funnel: funnel)
        if let failure {
            InlineMessage.error(failure)
        }
        if !viewModel.preparingReports.isEmpty, viewModel.tab == .funnel {
            PreparingReportsNotice(appName: viewModel.app.name, kinds: viewModel.preparingReports, asked: viewModel.reports.firstChecked) {
                viewModel.isReportsPresented = true
            }
        }
        switch viewModel.tab {
        case .funnel:
            FunnelView(viewModel: viewModel, report: funnel) { finding, action in
                viewModel.markActed(finding)
                onAct(action, finding.title)
            }
        case .breakdown:
            if let table = viewModel.table {
                BreakdownView(viewModel: viewModel, table: table, onAct: onAct)
            }
        case .findings:
            FindingsView(viewModel: viewModel, waitingCount: waitingCount) { finding, action in
                viewModel.markActed(finding)
                onAct(action, finding.title)
            }
        case .changes:
            ChangesView(viewModel: viewModel) {
                onAct(.pricing(territory: nil), String(localized: "Price results are in Pricing → Results, per territory."))
            }
        case .subscriptions:
            SubscriptionsPaneView(viewModel: viewModel, onAct: onAct) {
                centered {
                    ContentUnavailableView {
                        Label("No subscription numbers", systemImage: "arrow.triangle.2.circlepath")
                    } description: {
                        Text(viewModel.dataset.salesState == .needsVendorNumber
                            ? String(localized: "Subscriptions come from Sales and Trends, which needs your vendor number.")
                            : String(localized: "Subscriptions come from Sales and Trends, which this key can’t read or hasn’t delivered yet."))
                    } actions: {
                        Button("Analytics Settings…") {
                            viewModel.openSettings(focus: viewModel.dataset.salesState == .needsVendorNumber ? .vendorNumber : .salesRole)
                        }
                    }
                }
            }
        case .stability:
            if let report = viewModel.stability {
                StabilityView(report: report, onAct: onAct)
            }
        }
    }
}
