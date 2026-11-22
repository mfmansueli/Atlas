//
//  MainWindowBackground.swift
//  Atlas
//

import Foundation

/// What the main window does for the menu bar (`BackgroundWork`), while
/// it's on screen or hidden: one pass over App Store Connect, and opening
/// a "Needs you" line's place.
@MainActor
struct MainWindowBackground {
    let library: AppListViewModel
    let navigator: WorkspaceNavigator
    let services: WorkspaceServices
    let releases: ReleaseStore
    let analytics: AnalyticsStore
    let reviews: ReviewsStore
    let artwork: EventArtworkStudio
    /// Custom product pages followed while App Review has them.
    let productPages: ProductPagesStore
    /// Starts Claude Code for Reply Automatically.
    let launcher: ClaudeCodeLauncher
    var autoReply: AutoReplyCenter = .shared
    /// The person's API key, which writes the replies when Claude Code
    /// can't start.
    var keyAssistant: KeyAssistantController?
    /// The first sync is still going: no check then.
    let isSyncing: () -> Bool
    let selectedRelease: () -> ReleaseViewModel?

    /// One pass over App Store Connect, every `CheckInterval` and on Check
    /// Now: the app list, the versions with App Review, approved or
    /// rolling out (saying so when one moved), the custom product pages
    /// with App Review (the same), Apple's new analytics
    /// reports (unless they're only read on opening Analytics) and the
    /// reviews when what's kept is old. Returns why App Store Connect
    /// couldn't be read, else nil.
    func check() async -> String? {
        guard !isSyncing() else { return nil }
        await library.load()
        if let problem = library.errorMessage { return problem }
        if let selected = library.selectedAppID, releases.appsInFlight.contains(selected) { await selectedRelease()?.load() }
        for text in await releases.checkOthers(apps: library.apps, except: library.selectedAppID, services: services.release) {
            navigator.toast = WorkspaceToast(message: ToastMessage(text: text))
        }
        for text in await checkProductPages() {
            navigator.toast = WorkspaceToast(message: ToastMessage(text: text))
        }
        if analytics.settings.refreshMode == .everyMorning {
            for app in library.apps where analytics.isDue(app.id) {
                await analytics.refresh(app.id, services: services.analytics)
            }
            for appID in analytics.consumeArrivals() {
                navigator.toast = .reportsArrived(appID: appID, appName: library.apps.first { $0.id == appID }?.name ?? appID)
            }
        }
        for app in library.apps {
            let known = Set(reviews.archive(for: app.id).reviews.map(\.id))
            await reviews.refreshIfStale(app, services: services.reviews)
            // The first read of an app's reviews isn't news.
            guard !known.isEmpty else { continue }
            let arrived = reviews.archive(for: app.id).reviews.filter { !known.contains($0.id) }
            AtlasNotifications.newReviews(arrived, appName: app.name, appID: app.id)
        }
        await replyAutomatically()
        let findings = library.apps.reduce(0) { $0 + analytics.newFindingCount(for: $1.id) }
        AtlasNotifications.analyticsFindings(findings, now: .now)
        return nil
    }

    /// Reply Automatically (board 58): Claude Code writes the new reviews'
    /// replies; the ones due go out.
    private func replyAutomatically() async {
        for app in library.apps where autoReply.rule(for: app.id).isOn {
            await autoReply.writeReplies(app: app, reviews: reviews, launcher: launcher, keyAssistant: keyAssistant)
        }
        await sendDueReplies()
    }

    /// Send Reply on a drafted reply's notification: sent as written, like
    /// the person's own Send Reply. Says so when Apple refuses it.
    func sendReplyFromNotification(appID: StoreApp.ID, reviewID: AppReview.ID) async -> Bool {
        let archive = reviews.archive(for: appID)
        guard let review = archive.review(id: reviewID), !review.hasReply, let suggestion = archive.openSuggestion(for: review) else {
            return false
        }
        do {
            let reply = try await services.reviews.sendReply(suggestion.text, to: reviewID)
            reviews.setReply(reply, reviewID: reviewID, for: appID)
            reviews.markReplySentByHand()
            autoReply.personReplied(to: reviewID, appID: appID)
        } catch {
            AtlasNotifier.shared.post(
                .pushFailed, title: String(localized: "The reply wasn’t sent"),
                body: String(localized: "\(error.localizedDescription) It waits under the review."),
                identifier: "autoreply.\(appID).\(reviewID)"
            )
        }
        return true
    }

    /// Every app's automatic replies whose wait is over go out; on every
    /// background tick, so “Sends by itself in 42 min” keeps its word.
    func sendDueReplies() async {
        for app in library.apps where autoReply.isActive(for: app.id) {
            await autoReply.sendDue(app: app, reviews: reviews, services: services.reviews)
        }
    }

    /// Reads the custom product pages of every app with one waiting for
    /// App Review or in review, and tells what moved.
    func checkProductPages() async -> [String] {
        var told: [String] = []
        for app in library.apps where productPages.followsReview(for: app.id) {
            guard let snapshot = try? await services.productPages.pages(for: app) else { continue }
            let moves = productPages.followReview(of: snapshot.pages, for: app.id)
            told += AtlasNotifications.productPagesMoved(moves, appName: app.name, appID: app.id)
        }
        return told
    }

    /// A "Needs you" line or Review & Push… from the menu bar.
    func open(_ destination: BackgroundDestination) {
        switch destination {
        case let .section(section, appID):
            navigator.open(section, appID: appID)
        case let .version(appID):
            navigator.open(.overview, appID: appID)
        case let .currentSection(section):
            navigator.open(section)
        case .reviewPush:
            navigator.reviewEveryApp()
        case let .eventArtwork(appID, eventID):
            // The event's page, where its concepts are.
            navigator.open(.inAppEvents, intent: .showInAppEvents(eventID: eventID), appID: appID)
            artwork.update(EventArtworkRun.Key(appID: appID, eventID: eventID)) { $0.isHidden = false }
        }
    }
}
