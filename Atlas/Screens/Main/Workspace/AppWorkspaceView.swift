//
//  AppWorkspaceView.swift
//  Atlas
//

import SwiftUI

/// The detail column for the selected app: the toolbar (board 57: the
/// section's title over its state, with “N not pushed” opening Review &
/// Push on that section; the Autopilot button, Refresh, Activity and
/// Review & Push; while the sidebar is hidden the section menu first) over
/// the current section, and the window's toasts (Suggest Everything's
/// total when it finishes).
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
    @Environment(ReviewsStore.self) private var reviewsStore: ReviewsStore?
    @Environment(AnalyticsStore.self) private var analytics: AnalyticsStore?
    @Environment(InAppEventsStore.self) private var eventsStore: InAppEventsStore?
    @Environment(WorkspaceSectionModels.self) private var sectionModels: WorkspaceSectionModels?
    @Environment(\.askCenterOverride) private var askCenterOverride
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var toolbarLayout = WorkspaceToolbarLayout()
    @State private var isAskingQuestion = false
    /// The App Store's average, for Ratings & Reviews' line.
    @State private var ratingAverage: Double?
    /// The guided runs, which the menu bar icon reads too.
    private var autopilot: AutopilotCenter { .shared }
    /// Reply Automatically (board 58).
    private var autoReply: AutoReplyCenter { .shared }

    private var askCenter: AssistantAskCenter { askCenterOverride ?? .shared }
    /// Make Review Screenshots… runs, which Pricing starts.
    private var reviewShots: ReviewShotsRunCenter { .shared }

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
            // The page doesn't show through the toolbar: the soft edge
            // left a scrolled page's text behind the title (Alba's
            // Overview), so the edge is hard. Only the page's: a toolbar
            // background would cover the sidebar's glass up to the top too.
            content
                // The line under the section's description: what waits.
                .environment(\.sectionSummary, sectionSummary)
                // A bar on a page's bottom edge ends above the chat's pill.
                .environment(\.chatCornerRoom, AssistantChatRoom.pageRoom)
                .pageControlSize()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollEdgeEffectStyle(.hard, for: .top)
                // The assistant chat in the corner (board 69), over the
                // section, above the toast while one shows (the workspace's or
                // the section's own: Pricing's, Store Page's…).
                .overlayPreferenceValue(ToastShownPreferenceKey.self, alignment: .bottomTrailing) { chatCorner(isSectionToastShown: $0) }
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { toolbarLayout.detailWidth = $0 }
        // “4.7 ★” in Ratings & Reviews' line, from the answers the
        // Ratings card keeps a day.
        .task(id: navigator.section == .reviews) {
            guard navigator.section == .reviews, let reviewsStore else { return }
            ratingAverage = await RatingsSummary.average(of: app, archive: reviewsStore.archive(for: app.id), services: services.reviews)
        }
        // The toast, or else what arrived out of sight: “3 new below”.
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
            } else {
                NewArrivalsBelowNotice().padding(Spacing.large)
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
            // Make Review Screenshots… says what it made, not where it waits.
            let ending = finished.subject == ReviewShotsAskPrompt.subject ? reviewShots.runEnded(appID: finished.appID) : nil
            navigator.toast = WorkspaceToast(message: ToastMessage(text: ending ?? finished.text))
        }
        .sheet(isPresented: $isAskingQuestion) {
            AutopilotQuestionSheet(client: clientName, appName: app.name) { question in
                startAsk(.askSomethingElse, question: question)
            }
            .pageControlSize()
        }
        .navigationTitle(app.name)
        .navigationSubtitle(app.bundleID)
        .toolbar(removing: .title)
        .toolbar {
            // The sections are in the sidebar; while it's hidden, the
            // toolbar has them as a menu, first.
            if !navigator.isSidebarShown {
                ToolbarItem(placement: .navigation) {
                    SectionMenuButton(counts: counts, selection: $navigator.section, startsOpen: Self.opensSectionMenu)
                        .reportsToolbarRoom(.sectionMenu)
                }
            }
            if toolbarLayout.showsTitle {
                ToolbarItem(placement: .navigation) {
                    WorkspaceToolbarTitle(title: navigator.section.toolbarTitle, status: sectionStatus, maxWidth: toolbarLayout.titleRoom) {
                        navigator.review(section: navigator.section)
                    }
                    // Off the sidebar's edge; after the section menu it has its gap.
                    .padding(.leading, navigator.isSidebarShown ? WorkspaceToolbarLayout.titleInset : 0)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            // Keeps the actions at the trailing edge.
            ToolbarSpacer(.flexible)
            // Its own capsule, drawn by the button so the light can run
            // along its edge: a request's token lands on it.
            ToolbarItem(placement: .primaryAction) {
                autopilotButton
                    .tourTip(.autopilot, arrowEdge: .bottom)
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    navigator.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh from App Store Connect (⌘R)")
                .accessibilityIdentifier("workspace.refreshButton")
                // As tall as Autopilot and Review & Push beside them.
                .controlSize(.large)
                Button {
                    navigator.isActivityPresented = true
                } label: {
                    Label("Activity", systemImage: "clock")
                }
                .help("Activity")
                .accessibilityIdentifier("workspace.activityButton")
                .controlSize(.large)
            }
            // Pro, while the person is on Free.
            if pro.isFree {
                ToolbarItem(placement: .primaryAction) {
                    ProToolbarButton { pro?.showPlans() }
                        .reportsToolbarRoom(.proButton)
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
                .tourTip(.reviewPush, arrowEdge: .bottom)
            }
        }
        // The items say how much room they take; the labels fold only
        // when it isn't there.
        .environment(\.reportToolbarRoom, ToolbarRoomReport { item, width in
            var layout = toolbarLayout
            if layout.report(item, width: width) { toolbarLayout = layout }
        })
        .onChange(of: navigator.isSidebarShown, initial: true) { _, shown in
            toolbarLayout.isSidebarShown = shown
        }
    }

    // MARK: - Autopilot

    /// The toolbar's Autopilot button.
    private var autopilotButton: some View {
        let run = autopilot.run(for: app.id)
        return AutopilotToolbarButton(
            items: autopilotItems,
            everythingTitle: navigator.section == .overview ? nil : String(localized: "Everything for \(app.name)…"),
            state: autopilotState(run: run),
            runProgress: runProgress(run),
            isCompact: toolbarLayout.isAutopilotCompact,
            onAction: runAutopilot,
            onOpenRun: openNeeds,
            onCancelRun: cancelRun(run),
            autoReplyPaused: autoReply.rule(for: app.id).isOn && !pro.isFree ? autoReply.rule(for: app.id).isPaused : nil,
            onPauseAutoReply: { autoReply.setPaused($0, for: app.id) },
            onAutoReplySettings: { navigator.open(.reviews, intent: .autopilot(.replyAutomatically), appID: app.id) },
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
            ask: askCenter.ask(for: app.id),
            failedRunID: failedRun?.id,
            onForgetFailure: { if let id = failedRun?.id { launcher.dismiss(id) } }
        )
    }

    /// The app's last Claude Code run, when it stopped with a problem and
    /// the person hasn't opened it yet.
    private var failedRun: ClaudeCodeRun? {
        guard let last = launcher.runs.last(where: { $0.appID == app.id }), last.failure != nil else { return nil }
        return last
    }

    /// The section's actions, named for this app.
    private var autopilotItems: [WorkspaceAutopilotItem] {
        let language = app.primaryLocale.flatMap { Locale.current.localizedString(forIdentifier: $0) }
        let detail = navigator.autopilotDetail
        return WorkspaceAutopilotAction.actions(for: navigator.section, detail: detail).map { action in
            WorkspaceAutopilotItem(
                action: action,
                title: action.title(version: version?.versionString, sourceLanguage: language, detail: detail),
                systemImage: action.systemImage,
                isPro: pro.isFree && action.paywall != nil,
                isEnabled: action == .makeReviewScreenshots ? reviewShotsNote.isEnabled : true,
                note: action == .makeReviewScreenshots ? reviewShotsNote.text : nil
            )
        }
    }

    /// What the button says, from what the menu bar icon reads too.
    private func autopilotState(run: AutopilotRun?) -> WorkspaceAutopilotState {
        var inputs = WorkspaceAutopilotState.Inputs(
            askSubject: askCenter.ask(for: app.id)?.subject,
            workingClient: assistants.isWorking ? assistants.workingClient : nil,
            isSuggestingEverything: suggestions.run.map { $0.isRunning && $0.appID == app.id } ?? false,
            launchedRuns: launcher.activeRuns.count { $0.appID == app.id },
            autoReplyNeeds: autoReply.needsYouCount(for: app.id),
            failure: failedRun?.failure?.title
        )
        if let run {
            if run.stage.isRunning, run.finishedAt == nil {
                inputs.screenshotRunWorking = GuidedRunProgress.make(run, now: .now).title
            } else {
                inputs.screenshotRunNeeds = WorkspaceAutopilotState.screenshotNeeds(run)
            }
        }
        if let shots = reviewShots.run(for: app.id) {
            if shots.isWorking {
                inputs.reviewShotsWorking = shots.toolbarText
                inputs.reviewShotsProgress = shots.fraction
            } else {
                inputs.reviewShotsNeeds = shots.needs
                inputs.reviewShotsReady = shots.readyText
            }
        }
        let rule = autoReply.rule(for: app.id)
        if navigator.section == .reviews, rule.isOn, !pro.isFree {
            inputs.autoReplyOn = WorkspaceAutopilotState.autoReplyLine(isPaused: rule.isPaused, sentToday: autoReply.sentToday(for: app.id))
        }
        return WorkspaceAutopilotState(inputs)
    }

    /// The purple button: the guided run's step, else the reviews Reply
    /// Automatically left for the person.
    private func openNeeds() {
        let guided = autopilot.run(for: app.id)
        let guidedNeedsOrRuns = guided.map { WorkspaceAutopilotState.screenshotNeeds($0) != nil || $0.stage.isRunning } ?? false
        if reviewShots.run(for: app.id) != nil, !guidedNeedsOrRuns {
            navigator.open(.subscriptionPricing, appID: app.id)
        } else if let run = autopilot.run(for: app.id), WorkspaceAutopilotState.screenshotNeeds(run) != nil || run.stage.isRunning {
            openRun()
        } else if autoReply.needsYouCount(for: app.id) > 0 {
            navigator.open(.reviews, appID: app.id)
        } else {
            openRun()
        }
    }

    /// Runs one of the button's actions: Pro's ask for the paywall on Free;
    /// a section's own flow opens there; the rest ask Claude Code.
    private func runAutopilot(_ action: WorkspaceAutopilotAction) {
        if let paywall = action.paywall {
            pro.require(paywall) { perform(action) }
        } else {
            perform(action)
        }
    }

    private func perform(_ action: WorkspaceAutopilotAction) {
        switch action {
        case .suggestEverything: suggestEverything()
        case .suggestTexts: navigator.open(.storePage, intent: .askForSuggestions(.storePage), appID: app.id)
        case .translateNewLanguage: navigator.open(.storePage, intent: .translateMissing, appID: app.id)
        case .suggestAnswers: navigator.open(.appInformation, intent: .askForSuggestions(.appInformation), appID: app.id)
        case .checkPrivacy: navigator.open(.appInformation, intent: .openAppInformationPage(.appPrivacy), appID: app.id)
        case .askSomethingElse: isAskingQuestion = true
        case .makeScreenshots, .makeAppPreview, .makeArtwork, .suggestPages, .makePageScreenshots, .makeEventArtwork, .replyAutomatically,
             .makeReviewScreenshots:
            if let section = action.section { navigator.open(section, intent: .autopilot(action), appID: app.id) }
        default: startAsk(action)
        }
    }

    /// The assistant's name, for the requests' words.
    private var clientName: String {
        assistants.sessions.first?.displayName ?? MCPClientKind.claudeCode.title
    }

    /// Asks Claude Code from the toolbar, or copies the request to paste.
    private func startAsk(_ action: WorkspaceAutopilotAction, question: String? = nil) {
        let language = app.primaryLocale.flatMap { Locale.current.localizedString(forIdentifier: $0) }
        guard let ask = WorkspaceAutopilotAsk.make(
            action, app: app.name, version: version?.versionString, sourceLanguage: language, question: question
        ) else { return }
        let client = clientName
        switch AssistantAskStarter.start(ask, app: app, client: client, launcher: launcher, askCenter: askCenter, reduceMotion: reduceMotion) {
        case .sent: break
        case .copied: navigator.toast = WorkspaceToast(message: ToastMessage(text: AssistantAskStarter.copiedText(client: client)))
        case .busy: navigator.toast = WorkspaceToast(message: ToastMessage(text: AssistantAsk.busyTitle(client: client)))
        }
    }

    /// The guided run at its step, in Screenshots.
    private func openRun() {
        navigator.open(.screenshots, intent: .autopilot(.makeScreenshots), appID: app.id)
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

    /// Screenshot proposals waiting per app, and their sheet.
    private var screenshotDocuments: ScreenshotsDocumentCenter? {
        services.screenshots.documentCenter
    }

    @ViewBuilder
    private var content: some View {
        switch navigator.section {
        case .overview:
            OverviewSectionView(
                app: app, services: services.storePage, reviews: services.reviews,
                complianceAnswers: SectionBadgeCounts.complianceCount(
                    appID: app.id, model: sectionModels?.keptModels(for: app.id)?.appInformation, notes: services.appInformation.notes
                )
            )
        case .subscriptionPricing:
            PricingSectionView(
                app: app, services: services.pricing, retention: services.retention, appPriceAvailability: services.appPriceAvailability
            )
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
        case .nominations:
            NominationsSectionView(app: app, services: services)
        }
    }
}

// MARK: - Section summary

extension AppWorkspaceView {
    /// “3 suggestions · about 2 min · 2 in Review & Push” at the top of
    /// the section, from the same counts as the toolbar's line.
    var sectionSummary: SectionSummary? {
        let status = sectionStatus
        return SectionSummary.make(section: status.section, suggestions: status.waiting, notPushed: status.notPushed)
    }
}

// MARK: - Make Review Screenshots…

extension AppWorkspaceView {
    /// The guided run's progress, else the review screenshot run's.
    private func runProgress(_ run: AutopilotRun?) -> GuidedRunProgress? {
        if let run, run.stage.isRunning { return GuidedRunProgress.make(run, now: .now) }
        return reviewShotsProgress
    }

    /// Cancel Run…, for the guided run or the review screenshot run.
    private func cancelRun(_ run: AutopilotRun?) -> (() -> Void)? {
        if let run, AutopilotCenter.cancellableStages.contains(run.stage) {
            return { autopilot.cancelRun(appID: app.id) }
        }
        guard reviewShots.workingRun(for: app.id) != nil else { return nil }
        return { cancelReviewShots() }
    }

    /// Make Review Screenshots…'s note: “3 missing”, “Running”, “All set”.
    private var reviewShotsNote: (text: String?, isEnabled: Bool) {
        reviewShots.menuNote(for: app.id)
    }

    /// The review screenshot run's line in the menu, while it captures.
    private var reviewShotsProgress: GuidedRunProgress? {
        reviewShots.workingRun(for: app.id).map {
            GuidedRunProgress(title: $0.toolbarText, fraction: $0.fraction, line: $0.menuText)
        }
    }

    /// Cancel Run… on a review screenshot run: Claude Code stops; what it
    /// already made stays as suggestions.
    private func cancelReviewShots() {
        if let runID = askCenter.ask(for: app.id)?.runID { launcher.stop(runID) }
        reviewShots.clear(appID: app.id)
        navigator.toast = WorkspaceToast(message: ToastMessage(text: String(localized: "Run cancelled. Finished screenshots stay as suggestions.")))
    }
}

// MARK: - Toast

extension AppWorkspaceView {
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
}

// MARK: - Debug

extension AppWorkspaceView {
    /// A DEBUG scene that opens with the section menu showing.
    private static var opensSectionMenu: Bool {
        #if DEBUG
        NavigationDebugLaunch.opensSectionMenu
        #else
        false
        #endif
    }
}

// MARK: - Chat

extension AppWorkspaceView {
    private func chatCorner(isSectionToastShown: Bool) -> some View {
        AssistantChatCorner(
            context: chatContext, client: MCPClientKind.claudeCode.title, canAsk: canChat,
            onConnect: { navigator.isAssistantSetupPresented = true },
            onShow: { navigator.open($0, intent: AssistantChatSuggestions.intent(showing: $0), appID: app.id) },
            onReview: { section in
                if let section { navigator.review(section: section) } else { navigator.isReviewPresented = true }
            }
        )
        .padding(.trailing, AssistantChatRoom.trailingInset)
        .padding(.bottom, AssistantChatRoom.bottomPadding(isToastShown: navigator.toast != nil || isSectionToastShown))
        .animation(MotionTiming.fast.animation, value: isSectionToastShown)
    }

    /// Where the chat's questions are asked from.
    private var chatContext: AssistantChatContext {
        AssistantChatContext(appID: app.id, appName: app.name, section: navigator.section, version: version?.versionString, country: chatCountry)
    }

    /// Pricing's chosen country (“Preview in”), for the chat's chip.
    private var chatCountry: String? {
        guard navigator.section == .subscriptionPricing, let pricing = sectionModels?.keptModels(for: app.id)?.pricing else { return nil }
        return TerritoryCatalog.standard.territory(alpha3: pricing.previewTerritoryID)?.name
    }

    /// The chat can start Claude Code: the helper is saved and found it,
    /// or hasn't been looked at yet (a question looks first).
    private var canChat: Bool {
        switch launcher.helper {
        case .notInstalled, .claudeMissing, .outdated, .failed: false
        case .unknown, .checking, .ready, .atlasReplaced: true
        }
    }
}

// MARK: - Title

extension AppWorkspaceView {
    /// “32 suggestions in 6 languages · 3 not pushed” under the section's
    /// title; on Overview, the app and its version.
    private var sectionStatus: WorkspaceSectionStatus {
        let section = navigator.section
        var notPushed = changes.changes(for: app.id, section: section).count
        if section == .screenshots {
            notPushed += push.screenshots.plans(for: [app.id]).reduce(0) { $0 + $1.items.count }
            notPushed += push.screenshots.extras.plans(for: [app.id]).reduce(0) { $0 + $1.items.count }
        }
        let lead = section == .overview ? [app.name, version?.line].compactMap(\.self).joined(separator: " · ") : nil
        let rule = autoReply.rule(for: app.id)
        let note = section == .reviews && rule.isOn && !pro.isFree
            ? (rule.isPaused ? String(localized: "auto-reply paused") : String(localized: "auto-reply on")) : nil
        let waiting = section == .analytics ? analytics?.newFindingCount(for: app.id) ?? 0 : counts.count(for: section)
        return WorkspaceSectionStatus(
            section: section, waiting: waiting, notPushed: notPushed, lead: lead, note: note, facts: sectionFacts(for: section)
        )
    }

    /// What the section's line says besides its count, from what the
    /// section (or its read ahead) already read.
    private func sectionFacts(for section: AppWorkspaceSection) -> WorkspaceSectionStatus.Facts {
        var facts = WorkspaceSectionStatus.Facts()
        let kept = sectionModels?.keptModels(for: app.id)
        switch section {
        case .storePage:
            facts.languages = Set(suggestions.toReview(for: app.id, area: .storePage).compactMap { suggestion -> String? in
                guard case let .storePage(code) = suggestion.target.scope else { return nil }
                return code
            }).count
        case .productPages:
            if let model = kept?.productPages, model.state.value != nil { facts.pages = model.pages.count }
        case .inAppEvents:
            if let model = kept?.events, model.state.value != nil {
                facts.events = model.events.count
                facts.eventsNeedingArtwork = model.events.count { WorkspaceSectionStatus.Facts.waitsForArtwork($0) && !model.missingArt(of: $0).isEmpty }
            } else if let read = eventsStore?.lastRead(for: app.id) {
                facts.events = read.count
                facts.eventsNeedingArtwork = WorkspaceSectionStatus.Facts.eventsNeedingArtwork(read)
            }
        case .reviews:
            facts.rating = ratingAverage
            if let archive = reviewsStore?.archive(for: app.id), archive.fetchedAt != nil { facts.withoutReply = archive.needsReplyCount }
        case .analytics:
            facts.days = kept?.analytics?.days
        default:
            break
        }
        return facts
    }
}
