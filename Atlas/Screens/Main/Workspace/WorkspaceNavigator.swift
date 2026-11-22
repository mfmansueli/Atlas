//
//  WorkspaceNavigator.swift
//  Atlas
//

import Foundation
import Observation

/// The main window's navigation state: which section shows, the sheets the
/// toolbar opens, and a pending intent for the section to act on. Shared
/// through the environment so menus, quick actions and sections can steer
/// the window.
@MainActor
@Observable
final class WorkspaceNavigator {
    var section: AppWorkspaceSection
    /// Review & Push (⇧⌘P).
    var isReviewPresented = false
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
    /// The detail page open in the section (an event, a product page),
    /// whose action the Autopilot button leads with; the section sets and
    /// clears it.
    var autopilotDetail: WorkspaceAutopilotDetail?
    /// Activity history (the toolbar clock).
    var isActivityPresented = false
    /// Set by Activity's "Restore Previous Values": Review & Push opens once
    /// Activity has closed (macOS shows one sheet at a time).
    var opensReviewAfterActivity = false
    /// "Set Up Your AI Assistant" (the Assistant button, the overview, the
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
    /// Bumped by Refresh (⌘R). The library and every section reload when it
    /// changes (`.onChange(of: navigator.refreshCount)`).
    private(set) var refreshCount = 0

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

    /// Follows an Analytics finding to the section where the fix is made.
    func follow(_ action: FindingAction, origin: AnalyticsOrigin) {
        if action.isInsideAnalytics {
            openAnalytics(action == .billing ? .subscriptions : .stability, pane: action == .billing ? .billing : nil, appID: origin.appID)
            return
        }
        analyticsOrigin = origin
        switch action {
        case let .storePage(locale): open(.storePage, intent: locale.map(WorkspaceIntent.showLanguage), appID: origin.appID)
        case .screenshots: open(.screenshots, appID: origin.appID)
        case let .pricing(territory): open(.subscriptionPricing, intent: territory.map(WorkspaceIntent.showTerritoryPrice), appID: origin.appID)
        case .retention: open(.subscriptionPricing, intent: .showRetention, appID: origin.appID)
        case .inAppTexts: open(.storePage, appID: origin.appID)
        case let .productPage(name): open(.productPages, intent: .showProductPage(name: name), appID: origin.appID)
        case .stability, .billing: break
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
    }

    /// Closes Activity and opens Review & Push after it.
    func showReviewAfterActivity() {
        opensReviewAfterActivity = true
        isActivityPresented = false
    }

    /// Called when Activity closed.
    func activityDidClose() {
        guard opensReviewAfterActivity else { return }
        opensReviewAfterActivity = false
        isReviewPresented = true
    }

    /// Overview, starting Suggest Everything.
    func suggestEverything() {
        open(.overview)
        requestsSuggestEverything = true
    }

    /// Reloads everything from App Store Connect.
    func refresh() {
        refreshCount += 1
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
