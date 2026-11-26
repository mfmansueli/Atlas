//
//  AppInformationContentView.swift
//  Atlas
//

import SwiftUI

/// App Information as board 88 lays it out: the top (the page's sentence,
/// how many suggestions wait, Accept n on This Page and Accept All Pages),
/// the strip of the seven pages, then the open page with its fields the
/// whole width, with the accessibility editor sheet and the toast. App
/// Privacy lays out its own columns and scrolling under the same top and
/// strip.
struct AppInformationContentView: View {
    @Bindable var viewModel: AppInformationViewModel

    @Environment(\.undoManager) private var undoManager
    @Environment(AppPreferences.self) private var preferences
    @Environment(WorkspaceNavigator.self) private var navigator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                AppInformationTopBar(viewModel: viewModel)
                AppInformationPageStrip(viewModel: viewModel)
                AppInformationAcceptsRightAwayLine(viewModel: viewModel)
            }
            .padding(.horizontal, Spacing.xLarge)
            .padding(.top, Spacing.small)
            if viewModel.page == .appPrivacy {
                AppPrivacyPageView(viewModel: viewModel.privacy)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.large) {
                        refreshBanner
                        page
                    }
                    .padding(.vertical, Spacing.large)
                    .padding(.horizontal, Spacing.xLarge)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .leavesChatRoom()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("appInformation.pageContent")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.content)
        .overlay(alignment: .bottom) {
            if let toast = viewModel.suggestionToast {
                ActionToast(message: toast) {
                    viewModel.undoLastSuggestionBatch()
                } onAction: {
                    viewModel.suggestionToast = nil
                    navigator.isReviewPresented = true
                } onDismiss: {
                    if viewModel.suggestionToast == toast { viewModel.suggestionToast = nil }
                }
                .padding(.bottom, Spacing.large)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let toast = viewModel.toast {
                AppInformationToast(text: toast) { viewModel.toast = nil }
                    .padding(.bottom, Spacing.large)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: viewModel.toast)
        .animation(.default, value: viewModel.suggestionToast)
        .onAppear { viewModel.undoManager = undoManager }
        .onChange(of: undoManager) { viewModel.undoManager = undoManager }
        .sheet(item: $viewModel.editor) { item in
            AccessibilityEditorSheet(viewModel: viewModel, draft: viewModel.editor ?? item)
        }
        .sheet(isPresented: $viewModel.isAcceptAllPresented) {
            AcceptAllSheet(selection: viewModel.acceptAllSelection()) {
                viewModel.isAcceptAllPresented = false
            } onAccept: { ids, dontAskAgain in
                viewModel.isAcceptAllPresented = false
                if dontAskAgain { preferences.acceptsAllWithoutAsking = true }
                viewModel.acceptSuggestions(ids: ids, turnedOffAsking: dontAskAgain)
            }
        }
    }

    @ViewBuilder
    private var page: some View {
        switch viewModel.page {
        case .accessibility: AccessibilityPageView(viewModel: viewModel)
        case .appPrivacy: EmptyView()
        case .general, .appCompliance, .ageRating, .appReview, .exportCompliance:
            if viewModel.isLoaded {
                loadedPage
            } else if let message = viewModel.errorMessage {
                AppInformationLoadErrorView(message: message) {
                    Task { await viewModel.loadContent() }
                }
            } else {
                AppInformationPageSkeleton()
            }
        }
    }

    @ViewBuilder
    private var loadedPage: some View {
        switch viewModel.page {
        case .general: GeneralPageView(viewModel: viewModel)
        case .appCompliance: AppCompliancePageView(viewModel: viewModel)
        case .ageRating: AgeRatingPageView(viewModel: viewModel)
        case .appReview: AppReviewPageView(viewModel: viewModel)
        case .exportCompliance: ExportCompliancePageView(viewModel: viewModel)
        case .accessibility, .appPrivacy: EmptyView()
        }
    }

    /// A reload failed after the pages had loaded: they stay, with why.
    @ViewBuilder
    private var refreshBanner: some View {
        if viewModel.isLoaded, let message = viewModel.errorMessage, viewModel.page != .accessibility, viewModel.page != .appPrivacy {
            Banner(kind: .apiError, title: String(localized: "Couldn’t refresh app information"), message: message) {
                Button(String(localized: "Try Again")) {
                    Task { await viewModel.loadContent() }
                }
            }
            .padding(.horizontal, -Spacing.large)
            .accessibilityIdentifier("appInformation.refreshError")
        }
    }
}
