//
//  AppWorkspaceView.swift
//  Atlas
//

import SwiftUI

/// The detail column for the selected app: the toolbar (the Assistant
/// button, Refresh, Activity and Review & Push; while the sidebar is
/// hidden also the section menu and the app's title) over the current
/// section, and the window's toasts (Suggest Everything's total when it
/// finishes).
struct AppWorkspaceView: View {
    let app: StoreApp
    /// Every app in the library.
    let library: [StoreApp.ID]
    let services: WorkspaceServices
    /// The app's counts per section, for the section menu.
    let counts: SectionBadgeCounts
    /// The app's version, for the toolbar's title.
    let version: VersionStatusSummary?

    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(ChangeQueue.self) private var changes
    @Environment(PushController.self) private var push
    @Environment(MCPServerController.self) private var assistants
    @Environment(ClaudeCodeLauncher.self) private var launcher
    @Environment(FieldSuggestionStore.self) private var suggestions
    @Environment(ProGate.self) private var pro: ProGate?
    @Environment(\.askCenterOverride) private var askCenterOverride
    @State private var toolbarLayout = WorkspaceToolbarLayout()

    private var askCenter: AssistantAskCenter { askCenterOverride ?? .shared }

    var body: some View {
        @Bindable var navigator = navigator
        // The banner sits above the section, not in its safe area: one that
        // appears after a push ends would otherwise cover what the section
        // had already scrolled into place.
        VStack(spacing: 0) {
            if let notice = push.notice {
                PushNoticeBanner(notice: notice, push: push) {
                    navigator.isReviewPresented = true
                }
            }
            if let origin = navigator.analyticsOrigin, origin.appID == app.id, navigator.section != .analytics {
                FromAnalyticsBar(origin: origin) {
                    navigator.backToAnalytics()
                } onClose: {
                    navigator.analyticsOrigin = nil
                }
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollEdgeEffectStyle(.hard, for: .top)
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { toolbarLayout.detailWidth = $0 }
        .overlay(alignment: .bottom) {
            if let toast = navigator.toast {
                ActionToast(message: toast.message) {
                    undo(toast)
                } onAction: {
                    act(on: toast)
                } onDismiss: {
                    if navigator.toast?.id == toast.id { navigator.toast = nil }
                }
                .padding(Spacing.large)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: navigator.toast?.id)
        .onChange(of: suggestions.run) { old, new in
            guard let new, new.phase == .finished, old?.id != new.id || old?.phase != .finished else { return }
            navigator.toast = .finished(new)
        }
        // An asking button's request ended: where its suggestions are.
        .onChange(of: askCenter.finished) { _, finished in
            guard let finished else { return }
            navigator.toast = WorkspaceToast(message: ToastMessage(text: finished.text))
        }
        .navigationTitle(app.name)
        .navigationSubtitle(app.bundleID)
        .toolbar(removing: .title)
        .toolbar {
            // The sections are in the sidebar. While it's hidden, the
            // toolbar has them as a menu, and names the app and its version.
            if !navigator.isSidebarShown {
                ToolbarItem(placement: .navigation) {
                    SectionMenuButton(counts: counts, selection: $navigator.section, startsOpen: Self.opensSectionMenu)
                }
                if toolbarLayout.showsTitle(isSidebarShown: false) {
                    ToolbarItem(placement: .navigation) {
                        WorkspaceToolbarTitle(name: app.name, subtitle: version?.line ?? app.bundleID)
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
            }
            // Keeps the actions at the trailing edge.
            ToolbarSpacer(.flexible)
            // Its own capsule: a request's token lands on it.
            ToolbarItem(placement: .primaryAction) {
                assistantIndicator
            }
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    navigator.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh from App Store Connect (⌘R)")
                .accessibilityIdentifier("workspace.refreshButton")
                Button {
                    navigator.isActivityPresented = true
                } label: {
                    Label("Activity", systemImage: "clock")
                }
                .help("Activity")
                .accessibilityIdentifier("workspace.activityButton")
            }
            // Pro, while the person is on Free.
            if pro.isFree {
                ToolbarItem(placement: .primaryAction) {
                    ProToolbarButton { pro?.showPlans() }
                }
                .sharedBackgroundVisibility(.hidden)
            }
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {
                ReviewPushToolbarButton(
                    count: changes.totalCount + push.screenshots.imageCount + push.screenshots.extras.itemCount,
                    sending: push.sendingProgress,
                    isCompact: toolbarLayout.isReviewCompact
                ) {
                    navigator.isReviewPresented = true
                }
            }
        }
    }

    /// A DEBUG scene that opens with the section menu showing.
    private static var opensSectionMenu: Bool {
        #if DEBUG
        NavigationDebugLaunch.opensSectionMenu
        #else
        false
        #endif
    }

    /// The toolbar's Assistant button.
    private var assistantIndicator: some View {
        AssistantToolbarIndicator(
            activity: assistantActivity,
            status: assistants.assistantStatus,
            client: assistants.assistantClient,
            connection: assistants.connection(appID: app.id, appName: app.name, launcher: launcher),
            editsDrafts: assistants.editsDrafts,
            recentCalls: assistants.leadingClient.map { assistants.recentCalls(of: $0.name) } ?? [],
            center: screenshotDocuments,
            appName: push.appName,
            onReview: { client in navigator.reviewProposals(from: client) },
            isSuggestingEverything: suggestions.run?.isRunning == true,
            canAskAboutPage: navigator.section == .storePage || navigator.section == .appInformation,
            onAsk: askForSuggestions,
            onSuggestEverything: suggestEverything,
            onSetUp: { navigator.isAssistantSetupPresented = true },
            ask: askCenter.ask(for: app.id)
        )
    }

    private var assistantActivity: AssistantActivity {
        AssistantActivity(
            workingClient: assistants.isWorking ? assistants.workingClient : nil,
            changes: changes.changes,
            library: library,
            screenshotProposals: screenshotDocuments?.waitingClients(in: library) ?? [:],
            keepsVisible: screenshotDocuments?.presentedProposals != nil
        )
    }

    /// "Ask for Suggestions…": App Information's page when it's open, else
    /// the Store Page, which copies the prompt and waits.
    /// An API key only generates Store Page text.
    private func askForSuggestions() {
        let onInformation = navigator.section == .appInformation && !assistants.assistantStatus.isReady
        let area: SuggestionArea = onInformation ? .appInformation : .storePage
        navigator.open(area.section, intent: .askForSuggestions(area), appID: app.id)
    }

    /// Suggest Everything… starts it on Overview; Show Progress, while it
    /// runs, opens the run's Overview.
    private func suggestEverything() {
        if let run = suggestions.run, run.isRunning {
            navigator.open(.overview, appID: run.appID)
        } else {
            navigator.suggestEverything()
        }
    }

    private func undo(_ toast: WorkspaceToast) {
        guard let undo = toast.undo else { return }
        SuggestionRunAcceptance.undo(undo, queue: changes, store: suggestions)
        navigator.toast = nil
    }

    private func act(on toast: WorkspaceToast) {
        navigator.toast = nil
        switch toast.action {
        case let .openAnalytics(appID): navigator.open(.analytics, appID: appID)
        case let .openOverview(appID): navigator.open(.overview, appID: appID)
        case .suggestEverything: navigator.suggestEverything()
        case nil: break
        }
    }

    /// Screenshot proposals waiting per app, and their sheet.
    private var screenshotDocuments: ScreenshotsDocumentCenter? {
        services.screenshots.documentCenter
    }

    @ViewBuilder
    private var content: some View {
        switch navigator.section {
        case .overview:
            OverviewSectionView(app: app, services: services.storePage, reviews: services.reviews)
        case .subscriptionPricing:
            PricingSectionView(app: app, services: services.pricing, retention: services.retention)
        case .storePage:
            StorePageSectionView(app: app, services: services.storePage)
        case .screenshots:
            ScreenshotsSectionView(app: app, services: services.storePage)
        case .productPages:
            ProductPagesSectionView(app: app, services: services.productPages, screenshots: services.screenshots)
        case .appInformation:
            AppInformationSectionView(app: app, services: services.appInformation)
        case .analytics:
            AnalyticsSectionView(app: app, services: services, library: library)
        case .reviews:
            ReviewsSectionView(app: app, services: services.reviews)
        case .inAppEvents:
            InAppEventsSectionView(app: app, services: services)
        }
    }
}
