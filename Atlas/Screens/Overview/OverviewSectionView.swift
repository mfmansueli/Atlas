//
//  OverviewSectionView.swift
//  Atlas
//

import AppKit
import SwiftUI

/// The landing page for the selected app (⌘1), three lists beside the App
/// Store page: what the version still needs, the suggestions to review and
/// After release (README — redesign, November 22). It runs Suggest
/// Everything: Suggest Everything… starts Claude Code when its
/// helper is saved (else copies the prompt) and waits in a popover, and
/// once the assistant announces its plan the progress card takes the
/// assistant card's place until Done, with the run's strip under it.
struct OverviewSectionView: View {
    let app: StoreApp
    /// For the App Store page preview: the page's texts and screenshots.
    let services: any StorePageServices
    /// For the Ratings & Reviews card.
    let reviews: any ReviewsServices

    @Environment(AppSummaryStore.self) private var summaries
    @Environment(ChangeQueue.self) private var changes
    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(AppPreferences.self) private var preferences
    @Environment(MCPServerController.self) private var assistants
    @Environment(FieldSuggestionStore.self) private var suggestions
    @Environment(ClaudeCodeLauncher.self) private var launcher
    @Environment(AnalyticsStore.self) private var analytics
    @Environment(ReviewsStore.self) private var reviewsStore
    /// Nil in previews and scenes without the app's gate.
    @Environment(ProGate.self) private var pro: ProGate?
    /// What Suggest Everything covers, read once an assistant is connected.
    @State private var scope: SuggestEverythingScope?
    @State private var showsEverythingPopover = false
    /// The page the preview shows, read when Overview opens and on Refresh.
    @State private var content: StorePageContent?
    /// The window's kept models; nil in previews without the main window.
    @Environment(WorkspaceSectionModels.self) private var sectionModels: WorkspaceSectionModels?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                if isLoading {
                    OverviewSkeleton()
                } else {
                    if let message = errorMessage {
                        InlineMessage.error(message)
                            .accessibilityIdentifier("overview.error")
                    }
                    OverviewPageAndWaiting(
                        app: app, services: services, content: shownContent, storePage: storePage, newLanguages: newLanguages,
                        release: release, afterRelease: afterRelease
                    ) {
                        assistantCard
                        stabilityAlert
                    }
                }
            }
            // The prototype's Overview: 12 pt under the toolbar, 20 at the
            // sides, at most 1080 wide and centred.
            .padding(EdgeInsets(top: Spacing.medium, leading: Spacing.xLarge, bottom: Spacing.xxLarge, trailing: Spacing.xLarge))
            .frame(maxWidth: 1080 + 2 * Spacing.xLarge)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("workspace.overview")
        .task(id: app.id) { await summaries.load(app) }
        .task(id: app.id) { await reviewsStore.refreshIfStale(app, services: reviews) }
        .task(id: ContentKey(appID: app.id, refresh: navigator.refreshCount)) { await loadContent() }
        .task(id: ScopeKey(appID: app.id, isConnected: assistants.assistantStatus.isConnected)) {
            scope = nil
            await loadScope()
        }
        .task(id: navigator.requestsSuggestEverything) {
            guard navigator.requestsSuggestEverything else { return }
            navigator.requestsSuggestEverything = false
            // The popover needs its button on screen first.
            try? await Task.sleep(for: .milliseconds(300))
            suggestEverything()
        }
        .onChange(of: suggestions.run?.phase) {
            if suggestions.run?.phase != .waiting { showsEverythingPopover = false }
        }
        .onChange(of: launched?.phase) { launchedRunChanged() }
        #if DEBUG
        .task {
            if Self.debugRequestsSuggestEverything {
                Self.debugRequestsSuggestEverything = false
                navigator.requestsSuggestEverything = true
            }
        }
        #endif
    }

    private struct ScopeKey: Hashable {
        var appID: StoreApp.ID
        var isConnected: Bool
    }

    private struct ContentKey: Hashable {
        var appID: StoreApp.ID
        var refresh: Int
    }

    /// The page before `loadContent()` has run: the kept one, so the
    /// preview draws from the first frame.
    private var shownContent: StorePageContent? {
        content ?? sectionModels?.keptModels(for: app.id)?.overviewContent
    }

    /// The page for the preview: the one the window kept from the last
    /// time Overview showed, read again after Refresh, a push or when old.
    private func loadContent() async {
        let kept = sectionModels?.models(for: app.id)
        // Read ahead in the background: show what that read found.
        await kept?.finishWarming(.overview)
        guard !Task.isCancelled else { return }
        let refreshCount = navigator.refreshCount
        if let kept, let page = kept.overviewContent {
            content = page
            guard kept.needsLoad(.overview, refreshCount: refreshCount) else { return }
        }
        let loaded = await Self.readContent(for: app, services: services, into: kept, refreshCount: refreshCount)
        guard !Task.isCancelled else { return }
        content = loaded
    }

    /// Before an assistant is connected or a key set up, the card
    /// introducing them (until hidden); after, which one and what it can do;
    /// while Suggest Everything runs and until Done, its progress.
    @ViewBuilder
    private var assistantCard: some View {
        let status = assistants.assistantStatus
        if let run, run.phase != .waiting {
            SuggestionRunCard(
                run: run,
                toReviewCount: suggestions.toReview(in: run).count,
                onReview: review,
                onStop: {
                    suggestions.stopRun()
                    if let launched, launched.isActive { launcher.stop(launched.id) }
                },
                onDone: { suggestions.dismissRun() },
                onAcceptAll: { acceptAll(run) }
            )
            if let launched, launched.isActive || launched.failure != nil || !launched.denials.isEmpty {
                ClaudeCodeRunStatusView(run: launched)
            }
        } else if status.isConnected, let connection = assistants.connection(appID: app.id, appName: app.name, launcher: launcher) {
            AssistantConnectedCard(
                connection: connection,
                isPopoverPresented: $showsEverythingPopover,
                onSuggestEverything: suggestEverything,
                onDetails: { navigator.requestsAssistantPopover = true },
                onAction: { $0.perform(for: app, navigator: navigator, launcher: launcher) },
                popover: {
                    if let run, run.phase == .waiting {
                        SuggestEverythingPopover(
                            run: run,
                            scope: currentScope,
                            busyRequest: busyRequest,
                            onCopyAgain: { Self.copy(run.prompt) },
                            onCancel: {
                                showsEverythingPopover = false
                                suggestions.dismissRun()
                                if let launched, launched.isActive { launcher.stop(launched.id) }
                            }
                        )
                    }
                }
            )
        } else if case let .ready(client) = status, let summary = assistants.keyAssistant?.summary {
            AssistantConnectedCard(keyClient: client, summary: summary) {
                navigator.open(.storePage, intent: .askForSuggestions(.storePage))
            } onDetails: {
                navigator.requestsAssistantPopover = true
            } onAddAssistant: {
                navigator.assistantSetupMethod = .assistant
                navigator.isAssistantSetupPresented = true
            }
        } else if !status.canSuggest, preferences.showsAssistantIntro {
            AssistantIntroCard(appName: app.name, status: status) {
                navigator.isAssistantSetupPresented = true
            } onWhatItDoes: {
                navigator.requestsAssistantPopover = true
            } onHide: {
                preferences.showsAssistantIntro = false
            }
        }
    }

    /// The newest version crashes clearly more than the one before.
    @ViewBuilder
    private var stabilityAlert: some View {
        if let report = StabilityReport.make(analytics.reports(for: app.id), now: AnalyticsDay(analytics.now())), report.isWorse {
            StabilityAlertCard(
                report: report, phase: release?.phase, isPausing: release?.busyAction == .pause,
                onOpenStability: { navigator.openAnalytics(.stability, appID: app.id) },
                onPause: { Task { await release?.perform(.pause) } }
            )
        }
    }

    /// After release: the funnel's last 28 days, the reviews waiting for a
    /// reply and the product pages, one line each.
    private var afterRelease: [OverviewAfterReleaseRow] {
        let setup = analytics.setup(for: app.id)
        let report: FunnelReport? = setup == .ready
            ? FunnelReport.make(analytics.dataset(for: app, sellsSubscriptions: (pricing?.subscriptionCount ?? 1) > 0), days: 28)
            : nil
        return [
            .analytics(setup: setup, report: report, newFindings: analytics.findings(for: app.id).open.count),
            .reviews(archive: reviewsStore.archive(for: app.id), isPro: !(pro?.isFree ?? false)),
            .productPages(productPagesSummary),
        ]
    }

    /// The languages the app supports and its App Store page doesn't, once
    /// its assistant reported the project.
    private var newLanguages: NewLanguagesSummary? {
        guard let storePage, let appSupport = summaries.appSupport, appSupport.profile(for: app.id) != nil else { return nil }
        return NewLanguagesSummary(appID: app.id, storePage: storePage, appSupport: appSupport, changes: changes.changes(for: app.id))
    }

    private var isLoading: Bool {
        let states = [summaries.pricing[app.id]?.isLoading, summaries.storePage[app.id]?.isLoading, summaries.appInformation[app.id]?.isLoading]
        let nothingYet = pricing == nil && storePage == nil && summaries.appInformation[app.id]?.value == nil
        return nothingYet && (states.contains(true) || states.allSatisfy { $0 == nil })
    }

    /// The first failure, so a broken section doesn't hide the others.
    private var errorMessage: String? {
        summaries.pricing[app.id]?.errorMessage
            ?? summaries.storePage[app.id]?.errorMessage
            ?? summaries.appInformation[app.id]?.errorMessage
    }

    // MARK: - Suggest Everything

    /// Suggest Everything for this app, from Suggest Everything… until Done.
    private var run: SuggestionRun? {
        guard let run = suggestions.run, run.appID == app.id else { return nil }
        return run
    }

    /// A per-page Ask for this app that's still sending.
    private var busyRequest: AssistantSuggestionRequest? {
        guard let request = suggestions.request, request.appID == app.id, request.isReceiving else { return nil }
        return request
    }

    private var currentScope: SuggestEverythingScope {
        scope ?? SuggestEverythingScope(appName: app.name, versionString: storePage?.versionString)
    }

    private func loadScope() async {
        guard assistants.assistantStatus.isConnected, let workspace = assistants.workspace else { return }
        let loaded = await SuggestEverythingScope.load(app: app, in: workspace)
        guard !Task.isCancelled else { return }
        scope = loaded
    }

    /// Copies the prompt and waits for the assistant (again, when it already
    /// waits). With an API key it generates on the Store Page; with nothing
    /// set up, setup opens and says why.
    private func suggestEverything() {
        let status = assistants.assistantStatus
        guard case let .connected(client) = status else {
            if status.isReady {
                navigator.open(.storePage, intent: .askForSuggestions(.storePage))
            } else {
                navigator.setupStartsSuggestEverything = true
                navigator.isAssistantSetupPresented = true
            }
            return
        }
        if let run, run.phase == .waiting, run.client == client {
            // Started already: the popover shows that run.
            if launched == nil { Self.copy(run.prompt) }
        } else {
            let prompt = currentScope.prompt
            suggestions.beginRun(appID: app.id, client: client, prompt: prompt)
            if launcher.canStart {
                Task { await launch(prompt) }
            } else {
                Self.copy(prompt)
            }
        }
        showsEverythingPopover = true
        Task { await loadScope() }
    }

    /// The Claude Code run started for the current Suggest Everything.
    private var launched: ClaudeCodeRun? {
        guard let run = suggestions.run, run.appID == app.id else { return nil }
        return launcher.latestRun(appID: app.id, purpose: .suggestEverything, since: run.startedAt)
    }

    /// Starts Claude Code with `prompt`. With no folder chosen nothing was
    /// asked; if the helper went away, it's the paste after all.
    private func launch(_ prompt: String) async {
        guard await launcher.start(.suggestEverything, appID: app.id, appName: app.name, prompt: prompt) == nil else { return }
        if launcher.canStart {
            showsEverythingPopover = false
            suggestions.dismissRun()
        } else {
            Self.copy(prompt)
        }
    }

    /// The run ended: one that never announced a plan goes away (a failure
    /// or refused steps stay for the popover to explain); one that did is
    /// over with what arrived.
    private func launchedRunChanged() {
        guard let run = suggestions.run, run.appID == app.id, let launched else { return }
        switch (launched.phase, run.phase) {
        case (.finished, .waiting) where launched.denials.isEmpty:
            suggestions.dismissRun()
            navigator.toast = WorkspaceToast(message: ToastMessage(text: String(localized: "\(run.client) finished without sending suggestions.")))
        case (.stopped, .waiting):
            suggestions.dismissRun()
        case (.finished, .running):
            suggestions.endRun(id: run.id)
        case (.stopped, .running):
            suggestions.stopRun()
        default:
            break
        }
    }

    /// Review on a row of the progress card: the first language, page or
    /// device with suggestions.
    private func review(_ page: SuggestionPage) {
        if let information = page.appInformationPage {
            navigator.open(.appInformation, intent: .reviewPageSuggestions(information))
        } else {
            navigator.open(.storePage, intent: .reviewFieldSuggestions(.storePage))
        }
    }

    /// Accept All (n): every unreviewed suggestion from the run; the toast
    /// offers Undo.
    private func acceptAll(_ run: SuggestionRun) {
        guard let workspace = assistants.workspace else { return }
        let batch = suggestions.toReview(in: run)
        Task {
            let accepted = await SuggestionRunAcceptance.accept(batch, appID: run.appID, in: workspace, store: suggestions)
            guard accepted.count > 0 else { return }
            if let current = suggestions.run, current.id == run.id, suggestions.toReview(in: current).isEmpty {
                suggestions.dismissRun()
            }
            navigator.toast = .accepted(accepted.count, undo: accepted.undo)
        }
    }

    private static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - What the sections read

private extension OverviewSectionView {
    /// What the Custom Product Pages section read, kept by the window (or
    /// read ahead in the background).
    var productPagesSummary: ProductPagesOverviewSummary? {
        sectionModels?.keptModels(for: app.id)?.productPages.flatMap(ProductPagesOverviewSummary.make)
    }

    /// The version on its way to the App Store, read by the main window.
    var release: ReleaseViewModel? {
        sectionModels?.models(for: app.id).release
    }

    var pricing: PricingSummary? { summaries.pricing[app.id]?.value }
    var storePage: StorePageSummary? { summaries.storePage[app.id]?.value }
}
