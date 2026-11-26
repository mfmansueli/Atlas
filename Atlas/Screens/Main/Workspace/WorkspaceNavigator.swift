//
//  WorkspaceNavigator.swift
//  Atlas
//

import Foundation
import Observation

/// The main window's navigation state: which section shows, the sheets the
/// toolbar opens, a pending intent for the section to act on, and where
/// the window's Refresh stands. Shared through the environment so menus,
/// quick actions and sections can steer the window.
@MainActor
@Observable
final class WorkspaceNavigator {
    var section: AppWorkspaceSection
    /// Review & Push (⇧⌘P). Opening it picks its tab: the one asked for
    /// (`openActivity(highlighting:)`, `openReview(on:)`), else Activity
    /// when nothing waits (`ReviewPushTab.opening(pendingCount:)`), also
    /// when the button says Up to Date.
    var isReviewPresented = false {
        didSet {
            guard isReviewPresented, !oldValue, !isReviewTabChosen else { return }
            reviewTab = .opening(pendingCount: pendingReviewCount())
        }
    }

    /// What waits in Review & Push across all apps, as its button counts
    /// it; the main window sets it.
    @ObservationIgnored var pendingReviewCount: @MainActor () -> Int = { 0 }
    /// Review & Push was asked to open on `reviewTab`, whatever waits.
    private var isReviewTabChosen = false
    /// The source Review & Push opens filtered to, e.g. one assistant's
    /// proposals; cleared when it closes.
    var reviewSourceFilter: ChangeSourceFilter?
    /// Review & Push opened on every app's changes (the menu bar's
    /// Review & Push…), not only the selected app's.
    private(set) var reviewsEveryApp = false
    /// Review & Push opened by a custom product page's Push and Submit…:
    /// on that page's changes first (board 54).
    private(set) var reviewPage: ReviewPageFocus?
    /// Review & Push opened by the toolbar's “N not pushed”: on that
    /// section's changes first (board 57).
    private(set) var reviewSection: AppWorkspaceSection?
    /// ⌥⌘A: asks the toolbar's Autopilot button to run its action; the
    /// button clears it.
    var requestsAutopilot = false
    /// Show the Tour, from the sidebar's Help ▾ or macOS's Help menu: the
    /// main window starts the tips again on Overview.
    var requestsTour = false
    /// The detail page open in the section (an event, a product page),
    /// whose action the Autopilot button leads with; the section sets and
    /// clears it.
    var autopilotDetail: WorkspaceAutopilotDetail?
    /// The tab Review & Push shows (README-DS §15): To Push or Activity.
    var reviewTab = ReviewPushTab.toPush
    /// The push Activity highlights: the one that just ended ("Show in
    /// Activity" at the end of a push).
    var highlightedPushID: PushRecord.ID?
    /// Where the window's Refresh stands; the sidebar's Refresh button and
    /// the toolbar's status line show it (board 90).
    var refreshState = RefreshState.idle
    /// The Refresh that runs: the parts it still waits for.
    private(set) var refreshRun: RefreshRun?
    /// A push or a change asked for Refresh while one ran: another runs
    /// once it ends, so what changed is read.
    private var refreshesAgain = false
    /// The status line's Details… after a Refresh that failed.
    var isRefreshDetailsPresented = false
    /// The time a Refresh ends at; tests set it.
    @ObservationIgnored var now: () -> Date = { .now }
    /// The key's role when it can only read, for "View only"; the main
    /// window sets it (`RefreshRun.readOnlyRole(_:)`).
    @ObservationIgnored var readOnlyRole: @MainActor () -> String? = { nil }
    /// "Set Up Your Assistant" (the Assistant button, the overview, the
    /// suggestion bars).
    var isAssistantSetupPresented = false
    /// The method the setup sheet opens on, e.g. an assistant from "Add an
    /// MCP Assistant…"; nil opens where setup left off.
    var assistantSetupMethod: AssistantSetupMethod?
    /// Asks the toolbar's Assistant button to show its popover (the
    /// overview's What Can It Do? and Details); the button clears it.
    var requestsAssistantPopover = false
    /// Asks Overview to start Suggest Everything (the Assistant button, the
    /// Suggestions card, the toast after setup); Overview clears it.
    var requestsSuggestEverything = false
    /// Setup opened from Suggest Everything…: it says why, and when it ends
    /// connected, a toast offers Suggest Everything.
    var setupStartsSuggestEverything = false
    /// Set when an Analytics finding sent the person to another section:
    /// that section shows where they came from, with Back to Analytics.
    var analyticsOrigin: AnalyticsOrigin?
    /// The Analytics view Back to Analytics returns to; Analytics clears it.
    var requestedAnalyticsTab: AnalyticsTab?
    /// With `requestedAnalyticsTab` `.subscriptions`: the pane to show.
    var requestedSubscriptionsPane: SubscriptionsPane?
    /// The toast the whole window shows, over any section.
    var toast: WorkspaceToast?
    /// Submit for Review, from the Overview's version card or the sidebar's
    /// footer.
    var isSubmitPresented = false
    /// Whether the sidebar shows: hidden, the toolbar has the section menu
    /// and the app's title instead.
    var isSidebarShown = true
    /// The view that asked to hide the sidebar (Screenshots' Template tab);
    /// nil shows it. Only that view can bring it back, so one that's
    /// leaving can't undo another's request.
    private(set) var sidebarHider: UUID?
    /// What the current section should do next; nil when nothing is pending.
    private(set) var intent: WorkspaceIntent?
    /// The app to select first, e.g. for Show in Captions on another app's
    /// render; the main window selects it and clears it.
    private(set) var requestedAppID: StoreApp.ID?
    /// Bumped by Refresh (⌘R). The library, the version and the open section
    /// read again when it changes (`.onChange(of: navigator.refreshCount)`);
    /// the other sections when they're next opened (`SectionLoadStamp`).
    private(set) var refreshCount = 0
    /// Bumped when the person chooses the section that already shows (the
    /// sidebar, the section menu, ⌘1–⌘9): a section showing one item's
    /// page goes back to its list (Pricing's product page, board 73).
    private(set) var sectionChosenAgainCount = 0
    /// How each section's page action in the toolbar shows (board 80), as
    /// its page reports it (`reportsPageAction(_:for:)`); a section that
    /// hasn't reported has it on.
    var pageActionStates: [AppWorkspaceSection: WorkspacePageActionState] = [:]

    init(section: AppWorkspaceSection = .overview) {
        self.section = section
    }

    /// Switches to `section` (of `appID` when given) and leaves `intent`
    /// for it to handle.
    func open(_ section: AppWorkspaceSection, intent: WorkspaceIntent? = nil, appID: StoreApp.ID? = nil) {
        self.section = section
        self.intent = intent
        requestedAppID = appID
    }

    /// The person chose `section`: it opens, or, when it already shows, it
    /// goes back to its list (`sectionChosenAgainCount`).
    func choose(_ section: AppWorkspaceSection) {
        if section == self.section {
            sectionChosenAgainCount += 1
        } else {
            open(section)
        }
    }

    /// Follows an Analytics finding to the section where the fix is made;
    /// that section shows where the person came from (`analyticsOrigin`)
    /// until Back to Analytics or its ✕.
    func follow(_ action: FindingAction, origin: AnalyticsOrigin) {
        if let tab = action.analyticsTab {
            openAnalytics(tab, pane: action == .billing ? .billing : nil, appID: origin.appID)
            return
        }
        var origin = origin
        origin.section = action.section
        analyticsOrigin = origin
        switch action {
        case let .storePage(locale): open(.storePage, intent: locale.map(WorkspaceIntent.showLanguage), appID: origin.appID)
        case let .screenshots(locale):
            open(.screenshots, intent: locale.map { WorkspaceIntent.showScreenshotsLanguage($0, displayType: .iPhone) }, appID: origin.appID)
        case let .screenshotsOnDevice(displayType, locale):
            open(.screenshots, intent: .showScreenshotsLanguage(locale, displayType: displayType), appID: origin.appID)
        case let .pricing(territory): open(.subscriptionPricing, intent: territory.map(WorkspaceIntent.showTerritoryPrice), appID: origin.appID)
        case .pricingResults: open(.subscriptionPricing, intent: .showResults, appID: origin.appID)
        case .retention, .retentionLanguages: open(.subscriptionPricing, intent: .showRetention, appID: origin.appID)
        case .offerMessage: open(.subscriptionPricing, intent: .newRetentionMessage, appID: origin.appID)
        case .inAppTexts: open(.storePage, appID: origin.appID)
        case let .productPage(name): open(.productPages, intent: .showProductPage(name: name), appID: origin.appID)
        case let .pageScreenshots(name): open(.productPages, intent: .makePageScreenshots(name: name), appID: origin.appID)
        case .stability, .billing, .changes: break
        }
    }

    /// Analytics on `tab` (and, in Subscriptions, `pane`): from a finding
    /// that stays inside Analytics, the Overview's stability alert or the
    /// Pricing → Retention banner.
    func openAnalytics(_ tab: AnalyticsTab, pane: SubscriptionsPane? = nil, appID: StoreApp.ID?) {
        requestedAnalyticsTab = tab
        requestedSubscriptionsPane = pane
        open(.analytics, appID: appID)
    }

    /// Back to Analytics, on the view the person left.
    func backToAnalytics() {
        guard let origin = analyticsOrigin else { return }
        analyticsOrigin = nil
        requestedAnalyticsTab = origin.tab
        open(.analytics, appID: origin.appID)
    }

    /// Asks the current section to do something without switching.
    func send(_ intent: WorkspaceIntent) {
        self.intent = intent
    }

    /// Opens Review & Push on every app's proposals from `client`, or every
    /// change when it's nil.
    func reviewProposals(from client: String?) {
        reviewSourceFilter = client.map(ChangeSourceFilter.assistant)
        isReviewPresented = true
    }

    /// Opens Review & Push on every app's changes.
    func reviewEveryApp() {
        reviewSourceFilter = nil
        reviewsEveryApp = true
        isReviewPresented = true
    }

    /// Opens Review & Push on one custom product page's changes.
    func review(page: ReviewPageFocus) {
        reviewSourceFilter = nil
        reviewsEveryApp = false
        reviewPage = page
        isReviewPresented = true
    }

    /// Opens Review & Push on one section's changes.
    func review(section: AppWorkspaceSection) {
        reviewSourceFilter = nil
        reviewsEveryApp = false
        reviewPage = nil
        reviewSection = section
        isReviewPresented = true
    }

    /// What Review & Push opens on: one assistant's proposals or every
    /// app's changes, or the custom product page or section that opened it.
    func configure(_ review: ReviewPushViewModel) {
        if let filter = reviewSourceFilter {
            review.scope = .allApps
            review.sourceFilter = filter
        } else if reviewsEveryApp {
            review.scope = .allApps
        } else if let reviewPage {
            review.focus(on: reviewPage)
        } else if let reviewSection {
            review.focus(on: reviewSection)
        }
    }

    /// Called when Review & Push closed.
    func reviewDidClose() {
        reviewSourceFilter = nil
        reviewsEveryApp = false
        reviewPage = nil
        reviewSection = nil
        isReviewTabChosen = false
        highlightedPushID = nil
    }

    /// Review & Push on `tab`, whatever waits.
    func openReview(on tab: ReviewPushTab) {
        isReviewTabChosen = true
        reviewTab = tab
        isReviewPresented = true
    }

    /// Back to To Push, e.g. after Activity's Restore Previous Values put
    /// the old values there.
    func showToPush() {
        reviewTab = .toPush
        highlightedPushID = nil
    }

    /// Overview, starting Suggest Everything.
    func suggestEverything() {
        open(.overview)
        requestsSuggestEverything = true
    }

    // MARK: - Refresh

    /// Refresh (⌘R, the sidebar's button): reads App Store Connect again
    /// for the app list, the version and the open section. Nothing while
    /// one runs, so a second click does nothing.
    func refresh() {
        guard !refreshState.isRefreshing else { return }
        let lastGood = lastGoodRead
        refreshRun = RefreshRun(lastUpdated: lastGood)
        refreshState = lastGood.map { .refreshing(lastUpdated: $0) } ?? refreshState.starting
        refreshCount += 1
    }

    /// Refresh after something changed App Store Connect (a push, a
    /// release action): now, or once the one that runs ends.
    func refreshAfterChange() {
        if refreshState.isRefreshing {
            refreshesAgain = true
        } else {
            refresh()
        }
    }

    /// One part of Refresh number `refreshCount` ended, with `problem`
    /// when it didn't read. Once the run is done, the state says how it
    /// went and the button works again.
    func finishRefresh(_ part: RefreshPart, problem: RefreshProblem? = nil, refreshCount: Int) {
        guard refreshCount == self.refreshCount, var run = refreshRun, run.finish(part, problem: problem) else { return }
        guard run.isDone else {
            refreshRun = run
            return
        }
        refreshRun = nil
        refreshState = run.state(at: now(), readOnlyRole: readOnlyRole())
        if refreshesAgain {
            refreshesAgain = false
            refresh()
        }
    }

    /// The window's first read of the app list ended: the time it's from,
    /// or what went wrong, for Refresh's tooltip and the status line.
    func noteFirstRead(problem: RefreshProblem?) {
        guard refreshState == .idle else { return }
        var run = RefreshRun(parts: [.apps], lastUpdated: nil)
        run.finish(.apps, problem: problem)
        refreshState = run.state(at: now(), readOnlyRole: readOnlyRole())
    }

    /// When the window last read App Store Connect well: offline keeps the
    /// time what shows is from.
    private var lastGoodRead: Date? {
        if case let .offline(since) = refreshState { return since }
        return refreshState.lastUpdated
    }

    // MARK: - Activity

    /// Review & Push on its Activity tab (⌘Y, Product → Activity, Show in
    /// Activity at the end of a push), highlighting `pushID` when given.
    func openActivity(highlighting pushID: PushRecord.ID? = nil) {
        isReviewTabChosen = true
        reviewTab = .activity
        highlightedPushID = pushID
        isReviewPresented = true
    }

    var hidesSidebar: Bool { sidebarHider != nil }

    /// Hides the sidebar for `owner`, or shows it again when `owner` asked
    /// to hide it.
    func hideSidebar(_ hide: Bool, for owner: UUID) {
        if hide {
            sidebarHider = owner
        } else if sidebarHider == owner {
            sidebarHider = nil
        }
    }

    /// The sidebar's version footer: the Submit sheet before submitting,
    /// else the Overview's version card.
    func openVersion(submitting: Bool) {
        if submitting {
            isSubmitPresented = true
        } else {
            open(.overview)
        }
    }

    /// Called by the main window once it has selected `requestedAppID`.
    func consumeAppRequest() {
        requestedAppID = nil
    }

    /// Called by the section once it has handled `intent`.
    func consume(_ intent: WorkspaceIntent) {
        if self.intent == intent { self.intent = nil }
    }
}
