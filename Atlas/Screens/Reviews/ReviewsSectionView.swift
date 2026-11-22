//
//  ReviewsSectionView.swift
//  Atlas
//

import SwiftUI

/// The Reviews section of an app's workspace (⌘8): builds the view model
/// over the shared store (the window keeps it while other sections show),
/// reads the reviews when what's on this Mac is old, and follows a group's
/// action to the section where it's done.
struct ReviewsSectionView: View {
    let app: StoreApp
    let services: any ReviewsServices

    @State private var viewModel: ReviewsViewModel?
    @Environment(ReviewsStore.self) private var store
    @Environment(WorkspaceNavigator.self) private var navigator
    /// Nil in previews and scenes without the app's gate: everything runs.
    @Environment(ProGate.self) private var pro: ProGate?
    /// The window's kept models; nil in previews without the main window.
    @Environment(WorkspaceSectionModels.self) private var sectionModels: WorkspaceSectionModels?

    var body: some View {
        Group {
            if let viewModel = shownModel, viewModel.app.id == app.id {
                content(viewModel)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("workspace.reviews")
        .task(id: app.id) { await start() }
        .onChange(of: navigator.refreshCount) {
            Task { await viewModel?.load(force: true) }
        }
        .onChange(of: navigator.intent) { handleIntent() }
        .onChange(of: pro.isFree) { viewModel?.isPro = !pro.isFree }
    }

    private func content(_ viewModel: ReviewsViewModel) -> some View {
        ReviewsScreen(viewModel: viewModel, onThemeAction: { act(on: $0, in: viewModel) }, onUpgrade: { pro?.showPlans() })
            .sheet(isPresented: Binding { viewModel.bulkPlan != nil } set: { if !$0 { viewModel.bulkPlan = nil } }) {
                if let plan = viewModel.bulkPlan {
                    ReviewBulkSheet(viewModel: viewModel, plan: plan)
                }
            }
            .sheet(isPresented: Binding { viewModel.isAutoReplySettingsPresented } set: { viewModel.isAutoReplySettingsPresented = $0 }) {
                AutoReplySettingsSheet(
                    appName: app.name, rule: viewModel.autoReplyRule, languages: viewModel.reviewLanguages, isPro: viewModel.isPro,
                    onSave: { viewModel.saveAutoReply($0) },
                    onTurnOff: { viewModel.turnOffAutoReply() },
                    onUpgrade: {
                        viewModel.isAutoReplySettingsPresented = false
                        pro?.showPlans()
                    }
                )
            }
            .sheet(isPresented: Binding { viewModel.isAutoReplyHistoryPresented } set: { viewModel.isAutoReplyHistoryPresented = $0 }) {
                AutoReplyHistorySheet(entries: viewModel.autoReplyHistory) { await viewModel.undoAutoReply($0) }
            }
            .overlay(alignment: .bottom) {
                if let toast = viewModel.toast {
                    ActionToast(message: toast) {
                        Task { await viewModel.undoReply() }
                    } onDismiss: {
                        if viewModel.toast == toast { viewModel.toast = nil }
                    }
                    .padding(.bottom, Spacing.large)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.default, value: viewModel.toast)
    }

    /// The kept model before `start()` has run, so a section read ahead (or
    /// opened before) shows its content from the first frame, not a
    /// skeleton.
    private var shownModel: ReviewsViewModel? {
        viewModel ?? sectionModels?.keptModels(for: app.id)?.reviews
    }

    private func start() async {
        let kept = sectionModels?.models(for: app.id)
        // Read ahead in the background: show what that read found.
        await kept?.finishWarming(.reviews)
        guard !Task.isCancelled else { return }
        let model = kept?.reviews ?? ReviewsViewModel(app: app, store: store, services: services)
        kept?.reviews = model
        model.isPro = !pro.isFree
        viewModel = model
        #if DEBUG
        if let launch = ReviewsDebugLaunch.pending {
            ReviewsDebugLaunch.pending = nil
            launch.apply(to: model)
        }
        #endif
        await model.load()
        handleIntent()
    }

    /// A group's button: Reply to All opens its sheet, Show Reviews
    /// filters the list, and the others open the section that does it.
    private func act(on summary: ReviewThemeSummary, in viewModel: ReviewsViewModel) {
        switch summary.theme.action {
        case .replyToAll:
            viewModel.openBulk(summary.theme)
        case .showReviews:
            viewModel.show(summary.theme)
        case let .openPricing(territory):
            navigator.open(.subscriptionPricing, intent: territory.map(WorkspaceIntent.showTerritoryPrice))
        case .suggestStorePage:
            navigator.open(.storePage, intent: .askForSuggestions(.storePage))
        }
    }

    /// The Overview's "Reply to All…": the most mentioned group that has
    /// reviews left to reply to; the toolbar's Reply Automatically….
    private func handleIntent() {
        guard let viewModel, viewModel.hasLoaded, navigator.requestedAppID.map({ $0 == app.id }) ?? true else { return }
        // The toolbar's Reply Automatically…: its settings, on Free too.
        if navigator.intent == .autopilot(.replyAutomatically) {
            navigator.consume(.autopilot(.replyAutomatically))
            viewModel.isAutoReplySettingsPresented = true
            return
        }
        guard navigator.intent == .replyToAllReviews else { return }
        navigator.consume(.replyToAllReviews)
        guard viewModel.isPro else {
            pro?.showPlans()
            return
        }
        if let summary = viewModel.themeSummaries.first(where: { $0.theme.action == .replyToAll && $0.replyCount > 0 }) {
            viewModel.openBulk(summary.theme)
        }
    }
}
