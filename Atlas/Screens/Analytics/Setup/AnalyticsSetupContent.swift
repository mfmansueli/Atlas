//
//  AnalyticsSetupContent.swift
//  Atlas
//

import SwiftUI

/// The page before the first reports (README-DS §16): Ask Apple for
/// Reports, waiting for Apple, a key without Admin, the first download.
/// While it shows, the Autopilot bar offers only “Ask What Analytics
/// Shows…”.
struct AnalyticsSetupContent: View {
    @Bindable var viewModel: AnalyticsViewModel

    /// The window's navigator; nil in previews.
    @Environment(WorkspaceNavigator.self) private var navigator: WorkspaceNavigator?

    var body: some View {
        page
            .onAppear { navigator?.autopilotDetail = .analyticsBeforeReports }
            .onDisappear {
                if navigator?.autopilotDetail == .analyticsBeforeReports { navigator?.autopilotDetail = nil }
            }
    }

    @ViewBuilder
    private var page: some View {
        switch viewModel.availability {
        case .notSetUp:
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
        case .needsAdminKey:
            centered {
                AnalyticsKeyCannotAskView(keyID: viewModel.keyID) {
                    Task { await viewModel.ask() }
                }
            }
        case let .downloading(finished):
            AnalyticsLoadingView(appName: viewModel.app.name, finished: finished)
        case let .waitingForApple(asked):
            AnalyticsWaitingView(
                appName: viewModel.app.name, asked: asked ?? viewModel.store.now(), lastChecked: viewModel.lastChecked, now: viewModel.store.now(),
                isChecking: viewModel.activity.isLoading, errorMessage: failure
            ) {
                Task { await viewModel.refresh(force: true) }
            }
        case .missingVendorNumber, .noSalesAccess, .partial, .stale, .ready:
            EmptyView()
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
        .leavesChatRoom()
    }
}
