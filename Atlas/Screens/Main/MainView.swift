//
//  MainView.swift
//  Atlas
//

import SwiftUI

/// The main window once an API key is connected: the app library in the
/// sidebar, the selected app's workspace in the detail column, and the
/// Review & Push and Activity sheets. Right after a key is connected it
/// shows "Loading your apps…" until the first sync is done. It asks App
/// Store Connect for the team's name once, for the account switcher. With
/// `prefetchesSections`, the open app's other sections are read ahead in
/// the background (`SectionPrefetcher`), so they open already loaded.
struct MainView: View {
    @State private var viewModel: AppListViewModel
    @State private var summaries: AppSummaryStore
    @State private var navigator: WorkspaceNavigator
    @State private var sectionModels = WorkspaceSectionModels()
    /// What covers the whole window, e.g. an event's artwork full size.
    @State private var cover = WindowCover()
    @State private var isSyncing: Bool
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    private let services: WorkspaceServices
    private let accounts: [TeamAccount]
    private let currentAccountID: TeamAccount.ID?
    private let onSelectAccount: (TeamAccount) -> Void
    private let onAddKey: () -> Void
    private let onFirstSyncFinished: () -> Void
    /// Cancel on "Reading your apps…"; nil hides it.
    private let onCancelFirstSync: (() -> Void)?
    private let onTeamNameFound: (String) -> Void
    /// Reads the open app's other sections ahead.
    private let prefetchesSections: Bool

    @Environment(ChangeQueue.self) private var changes
    @Environment(PushController.self) private var push
    @Environment(AppPreferences.self) private var preferences
    @Environment(PricingModeStore.self) private var pricingModes
    @Environment(MCPServerController.self) private var assistants
    @Environment(KeyAssistantController.self) private var keyAssistant
    @Environment(TranslationPreferences.self) private var translation
    @Environment(FieldSuggestionStore.self) private var suggestions
    @Environment(ClaudeCodeLauncher.self) private var launcher
    /// Nil in previews and scenes without the app's gate.
    @Environment(ProGate.self) private var pro: ProGate?
    @Environment(AnalyticsStore.self) private var analytics
    @Environment(ReviewsStore.self) private var reviews
    @Environment(EventArtworkStudio.self) private var artwork
    @Environment(InAppEventsStore.self) private var events
    @Environment(ProductPagesStore.self) private var productPages
    @Environment(ReleaseStore.self) private var releases
    /// The menu bar's view of what runs and what waits; nil in previews.
    @Environment(BackgroundWork.self) private var background: BackgroundWork?

    init(
        credentials: AppStoreConnectCredentials,
        accounts: [TeamAccount],
        isFirstSync: Bool = false,
        onSelectAccount: @escaping (TeamAccount) -> Void = { _ in },
        onAddKey: @escaping () -> Void = {},
        onFirstSyncFinished: @escaping () -> Void = {},
        onCancelFirstSync: (() -> Void)? = nil,
        onTeamNameFound: @escaping (String) -> Void = { _ in }
    ) {
        self.init(
            services: .live(client: AppStoreConnectClient(credentials: credentials)),
            accounts: accounts,
            currentAccountID: credentials.keyID,
            isFirstSync: isFirstSync,
            onSelectAccount: onSelectAccount,
            onAddKey: onAddKey,
            onFirstSyncFinished: onFirstSyncFinished,
            onCancelFirstSync: onCancelFirstSync,
            onTeamNameFound: onTeamNameFound,
            prefetchesSections: true
        )
    }

    /// With existing services — DEBUG scenes and previews, which read
    /// sections ahead only when asked (`prefetchesSections`), so their
    /// openings run on the models the sections make.
    init(
        services: WorkspaceServices,
        accounts: [TeamAccount] = [],
        currentAccountID: TeamAccount.ID? = nil,
        selectedAppID: StoreApp.ID? = nil,
        section: AppWorkspaceSection = .overview,
        presentedSheet: WorkspaceSheet? = nil,
        isFirstSync: Bool = false,
        onSelectAccount: @escaping (TeamAccount) -> Void = { _ in },
        onAddKey: @escaping () -> Void = {},
        onFirstSyncFinished: @escaping () -> Void = {},
        onCancelFirstSync: (() -> Void)? = nil,
        onTeamNameFound: @escaping (String) -> Void = { _ in },
        prefetchesSections: Bool = false
    ) {
        self.services = services
        self.prefetchesSections = prefetchesSections
        self.accounts = accounts
        self.currentAccountID = currentAccountID
        self.onSelectAccount = onSelectAccount
        self.onAddKey = onAddKey
        self.onFirstSyncFinished = onFirstSyncFinished
        self.onCancelFirstSync = onCancelFirstSync
        self.onTeamNameFound = onTeamNameFound
        _isSyncing = State(initialValue: isFirstSync)
        _viewModel = State(initialValue: AppListViewModel(services: services.appList, selectedAppID: selectedAppID))
        _summaries = State(initialValue: AppSummaryStore(services: services))
        let navigator = WorkspaceNavigator(section: section)
        #if DEBUG
        // A scene with the sidebar hidden, as the design's 860-point boards.
        if NavigationDebugLaunch.hidesSidebar { _columnVisibility = State(initialValue: .detailOnly) }
        #endif
        switch presentedSheet {
        case .review: navigator.isReviewPresented = true
        case let .proposals(client): navigator.reviewProposals(from: client)
        case .activity: navigator.isActivityPresented = true
        case .assistantSetup: navigator.isAssistantSetupPresented = true
        case nil: break
        }
        _navigator = State(initialValue: navigator)
    }

    var body: some View {
        content
            .sheet(isPresented: $navigator.isReviewPresented, onDismiss: navigator.reviewDidClose) {
                ReviewPushSheet(viewModel: reviewViewModel())
            }
            .sheet(isPresented: $navigator.isActivityPresented, onDismiss: navigator.activityDidClose) {
                ActivitySheet()
            }
            .sheet(isPresented: $navigator.isAssistantSetupPresented, onDismiss: assistantSetupDidClose, content: {
                AssistantSetupSheet(
                    assistants: assistants,
                    keyAssistant: keyAssistant,
                    appName: viewModel.selectedApp?.name ?? String(localized: "your app"),
                    appID: viewModel.selectedApp?.id,
                    launcher: launcher,
                    method: navigator.assistantSetupMethod,
                    reason: navigator.setupStartsSuggestEverything ? AssistantSetupSheet.suggestEverythingReason : nil
                )
            })
            // Show Output, for runs Atlas started from any screen.
            .sheet(item: shownRun) { run in
                ClaudeCodeRunOutputSheet(runID: run.id)
            }
            // Submit for Review, from the version card or the sidebar's footer.
            .sheet(isPresented: $navigator.isSubmitPresented) {
                if let release = selectedRelease {
                    SubmitForReviewSheet(viewModel: release)
                }
            }
            // The paywall, from whatever needed Pro or the toolbar's button.
            .sheet(item: Binding(get: { pro?.paywall }, set: { pro?.paywall = $0 })) { model in
                PaywallSheet(model: model) { continues in pro?.finish(model, continues: continues) }
            }
            // Free works on one app: another opens the paywall and the
            // selection stays where it was.
            .onChange(of: viewModel.selectedAppID) { old, new in
                guard let pro, let new, !pro.mayOpen(appID: new) else { return }
                viewModel.selectedAppID = old
                pro.require(.secondApp) { viewModel.selectedAppID = new }
            }
            .task { configurePush() }
            .task { attachAssistants() }
            .onDisappear { assistants.workspace = nil }
            .task { await loadLibrary() }
            // What the menu bar shows and the checks it makes on its own
            // (reviews, versions in flight, analytics reports).
            .task { attachBackgroundWork() }
            .onChange(of: viewModel.apps, initial: true) { background?.library = viewModel.apps }
            // The version's status, for the sidebar's footer, whatever section shows.
            .task(id: viewModel.selectedAppID) { await loadSelectedRelease() }
            // The open app's other sections, read ahead.
            .modifier(SectionPrefetchModifier(app: prefetchesSections && !isSyncing ? viewModel.selectedApp : nil, services: services, keyID: currentAccountID))
            // Refresh reads the version and its builds again too.
            .onChange(of: navigator.refreshCount) { Task { await selectedRelease?.load() } }
            .task {
                if let name = await viewModel.findTeamName() { onTeamNameFound(name) }
            }
            .onChange(of: navigator.hidesSidebar) {
                columnVisibility = navigator.hidesSidebar ? .detailOnly : .all
            }
            .onChange(of: columnVisibility, initial: true) {
                navigator.isSidebarShown = columnVisibility != .detailOnly
            }
            .onChange(of: navigator.requestedAppID) {
                guard let appID = navigator.requestedAppID else { return }
                viewModel.selectedAppID = appID
                navigator.consumeAppRequest()
            }
            .onChange(of: navigator.refreshCount) {
                summaries.invalidateAll()
                Task { await loadLibrary() }
                Task { await selectedRelease?.load() }
            }
            // Outermost, so the sheets see them too.
            .environment(cover)
            .environment(navigator)
            .environment(summaries)
            .environment(sectionModels)
            .focusedSceneValue(\.workspaceNavigator, isSyncing ? nil : navigator)
    }

    @ViewBuilder
    private var content: some View {
        if isSyncing {
            FirstSyncView(
                progress: FirstSyncProgress(
                    appCount: viewModel.hasLoaded ? viewModel.apps.count : nil,
                    syncedCount: viewModel.apps.count { summaries.isSettled($0.id) },
                    teamName: accounts.first { $0.id == currentAccountID && $0.isNamed }?.name,
                    syncedNames: viewModel.apps.filter { summaries.isSettled($0.id) }.map(\.name)
                ),
                onCancel: onCancelFirstSync
            )
        } else {
            library
        }
    }

    private var library: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            AppSidebar(
                viewModel: viewModel, summaries: summaries, accounts: accounts, currentAccountID: currentAccountID,
                counts: viewModel.selectedApp.map(counts) ?? SectionBadgeCounts(), version: viewModel.selectedApp.flatMap(versionSummary),
                onSelectAccount: onSelectAccount, onAddKey: onAddKey, onVersion: openVersion
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: Metrics.sidebarWidth, max: 360)
        } detail: {
            detail
        }
        .modifier(WindowCoverModifier(cover: cover))
    }

    @ViewBuilder
    private var detail: some View {
        if let app = viewModel.selectedApp {
            AppWorkspaceView(app: app, library: viewModel.apps.map(\.id), services: services, counts: counts(app), version: versionSummary(app))
                .id(app.id)
        } else if viewModel.isLoading, viewModel.apps.isEmpty {
            OverviewSkeleton()
                .padding(Spacing.xxLarge)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if !viewModel.apps.isEmpty {
            ContentUnavailableView("Select an app", systemImage: "sidebar.left", description: Text("Pick an app in the sidebar to localize it."))
        }
    }

    // MARK: - Sections and the version

    /// The app's counts per section, for the sidebar and the section menu.
    private func counts(_ app: StoreApp) -> SectionBadgeCounts {
        SectionBadgeCounts(
            appID: app.id,
            suggestions: suggestions,
            screenshots: services.screenshots.documentCenter,
            pricing: SectionBadgeCounts.pricingCount(appID: app.id, summaries: summaries, modes: pricingModes, changes: changes),
            extras: SectionBadgeCounts.Extras(
                newFindings: navigator.section == .analytics ? 0 : analytics.newFindingCount(for: app.id),
                // Suggested replies are Pro: in Free there are none to accept.
                reviewReplies: pro.isFree ? 0 : reviews.suggestionCount(for: app.id),
                eventLanguages: events.count(for: app.id, changes: changes.changes(for: app.id, section: .inAppEvents)),
                complianceAnswers: SectionBadgeCounts.complianceCount(
                    appID: app.id, model: sectionModels.models(for: app.id).appInformation, notes: services.appInformation.notes
                ),
                productPages: productPages.count(for: app.id)
            )
        )
    }

    /// The selected app's version on its way to the App Store: one model
    /// for the Overview's card, the Submit sheet and the sidebar's footer,
    /// kept with the app's other section models.
    private var selectedRelease: ReleaseViewModel? {
        guard let app = viewModel.selectedApp else { return nil }
        let kept = sectionModels.models(for: app.id)
        if let model = kept.release { return model }
        let model = ReleaseViewModel(app: app, services: services, store: releases, queue: changes, suggestions: suggestions, push: push, events: events)
        model.storePageModel = { [sectionModels, services, changes, suggestions, summaries, push] in
            await sectionModels.models(for: app.id).loadedStorePage {
                StorePageViewModel(app: app, services: services.storePage, queue: changes, suggestions: suggestions, summaries: summaries, push: push)
            }
        }
        model.onMessage = { [navigator] text in navigator.toast = WorkspaceToast(message: ToastMessage(text: text)) }
        model.onChanged = { [navigator, summaries] in
            summaries.invalidate(app.id)
            navigator.refresh()
        }
        kept.release = model
        return model
    }

    private func loadSelectedRelease() async {
        guard let release = selectedRelease else { return }
        await release.load()
        #if DEBUG
        ReleaseDebugLaunch.applyPending(to: release, navigator: navigator)
        #endif
    }

    /// "Version 1.4 · Not submitted yet": the status once read, else what
    /// the Store Page's summary knows.
    private func versionSummary(_ app: StoreApp) -> VersionStatusSummary? {
        releases.summary(for: app.id, model: sectionModels.models(for: app.id).release, storePage: summaries.storePage[app.id]?.value)
    }

    /// The sidebar's footer: the Submit sheet before submitting, else the
    /// Overview's version card.
    private func openVersion() {
        guard let app = viewModel.selectedApp else { return }
        navigator.openVersion(submitting: versionSummary(app)?.opensSubmit == true && selectedRelease?.status != nil)
    }

    /// Review & Push for the selected app, or for every app's proposals
    /// from one assistant when the toolbar indicator opened it.
    private func reviewViewModel() -> ReviewPushViewModel {
        let review = ReviewPushViewModel(
            queue: changes,
            push: push,
            selectedAppID: viewModel.selectedAppID,
            appName: { [viewModel] id in viewModel.apps.first { $0.id == id }?.name ?? id },
            pushConfirmation: preferences.pushConfirmation,
            confirmsPriceIncreases: preferences.confirmsPriceIncreases
        )
        if let filter = navigator.reviewSourceFilter {
            review.scope = .allApps
            review.sourceFilter = filter
        } else if navigator.reviewsEveryApp {
            review.scope = .allApps
        }
        return review
    }

    /// Points Review & Push at this account and reloads what a push changed.
    private func configurePush() {
        push.transport = services.push
        push.appName = { [viewModel] id in viewModel.apps.first { $0.id == id }?.name ?? id }
        push.onPushed = { [summaries, navigator] appIDs in
            for appID in appIDs {
                summaries.invalidate(appID)
            }
            navigator.refresh()
        }
        push.screenshots.attach(ScreenshotPushWorkspace(teamName: teamName, services: services, apps: loadedApps))
    }

    /// Setup opened from Suggest Everything… that ends with an assistant
    /// connected offers to start it.
    private func assistantSetupDidClose() {
        navigator.assistantSetupMethod = nil
        guard navigator.setupStartsSuggestEverything else { return }
        navigator.setupStartsSuggestEverything = false
        if case let .connected(client) = assistants.assistantStatus {
            navigator.toast = .connected(client)
        }
    }

    /// Lets connected assistants read and propose for this account, and
    /// the toolbar open any app's screenshot proposals.
    private func attachAssistants() {
        // So a project folder that builds another app is asked about.
        launcher.bundleIDLookup = { [viewModel] appID in viewModel.apps.first { $0.id == appID }?.bundleID }
        services.screenshots.documentCenter?.librarySource = { [viewModel, services] appID in
            guard let app = viewModel.apps.first(where: { $0.id == appID }),
                  let primaryLocale = app.primaryLocale.flatMap(StoreLocaleCatalog.locale(code:)) ?? StoreLocaleCatalog.locale(code: "en-US")
            else { return nil }
            return ScreenshotsDocumentCenter.Source(app: app, services: services.screenshots, primaryLocale: primaryLocale)
        }
        assistants.workspace = MCPWorkspace(
            teamName: teamName,
            // Product pages as the section read them, while that's fresh.
            services: services.keepingProductPages { [sectionModels, navigator] in sectionModels.freshProductPages($0, refreshCount: navigator.refreshCount) },
            changes: changes,
            pricingModes: pricingModes,
            apps: loadedApps,
            glossary: { [translation] in translation.glossary },
            commission: { [preferences] in Commission(preferenceRate: preferences.commissionRate) },
            suggestions: suggestions,
            push: { [push] in MCPPushSnapshot(push) }
        )
    }

    private var teamName: String {
        accounts.first { $0.id == currentAccountID }?.name ?? String(localized: "This account")
    }

    /// The library, loading it first when the sidebar hasn't yet.
    private var loadedApps: @MainActor () async throws -> [StoreApp] {
        { [viewModel] in
            if !viewModel.hasLoaded { await viewModel.load() }
            if let message = viewModel.errorMessage, viewModel.apps.isEmpty { throw MCPToolError.unavailable(message) }
            return viewModel.apps
        }
    }

    // MARK: - Background work

    /// Lets the menu bar check this account and open its places, while
    /// the window is on screen or hidden.
    private func attachBackgroundWork() {
        guard let background else { return }
        let handlers = MainWindowBackground(
            library: viewModel, navigator: navigator, services: services, releases: releases, analytics: analytics, reviews: reviews,
            artwork: artwork, isSyncing: { isSyncing }, selectedRelease: { selectedRelease }
        )
        background.library = viewModel.apps
        background.isFree = { [pro] in pro.isFree }
        background.checkHandler = { await handlers.check() }
        background.openHandler = { handlers.open($0) }
    }

    /// The run Show Output shows, as the sheet's item.
    private var shownRun: Binding<ShownRun?> {
        Binding { launcher.shownRunID.map(ShownRun.init) } set: { launcher.shownRunID = $0?.id }
    }

    private struct ShownRun: Identifiable {
        let id: ClaudeCodeRun.ID
    }

    /// The apps, then their summaries and, alongside, their icons: one
    /// request per app that doesn't hold up the first sync.
    private func loadLibrary() async {
        let viewModel = viewModel
        await viewModel.load()
        async let icons: Void = viewModel.loadIcons()
        await summaries.prefetch(viewModel.apps)
        if isSyncing, !Task.isCancelled {
            isSyncing = false
            onFirstSyncFinished()
        }
        await icons
    }
}
