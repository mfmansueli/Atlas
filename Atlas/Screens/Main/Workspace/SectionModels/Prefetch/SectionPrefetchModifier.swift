//
//  SectionPrefetchModifier.swift
//  Atlas
//

import SwiftUI

/// Reads `app`'s other sections ahead (`SectionPrefetcher`) with the
/// window's stores, from the moment it opens, and again after Refresh or a
/// push. Nil `app` reads nothing: no app is open, the first sync still
/// runs, or the window doesn't read ahead.
struct SectionPrefetchModifier: ViewModifier {
    let app: StoreApp?
    let services: WorkspaceServices
    /// The connected key, whose hourly quota the reads spend.
    let keyID: TeamAccount.ID?

    @Environment(WorkspaceSectionModels.self) private var sectionModels
    @Environment(WorkspaceNavigator.self) private var navigator
    @Environment(ChangeQueue.self) private var changes
    @Environment(AppSummaryStore.self) private var summaries
    @Environment(PushController.self) private var push
    @Environment(PushHistory.self) private var history
    @Environment(FieldSuggestionStore.self) private var suggestions
    @Environment(AppPreferences.self) private var preferences
    @Environment(PricingModeStore.self) private var pricingModes
    @Environment(ReviewsStore.self) private var reviews
    @Environment(InAppEventsStore.self) private var events
    @Environment(ProductPagesStore.self) private var productPages
    @Environment(AnalyticsStore.self) private var analytics
    @Environment(EventArtworkStudio.self) private var artwork
    /// For the team's name on App Compliance; nil in scenes without a session.
    @Environment(AppSession.self) private var session: AppSession?
    /// Nil in previews and scenes without the app's gate.
    @Environment(ProGate.self) private var pro: ProGate?

    func body(content: Content) -> some View {
        content
            .task(id: Key(appID: app?.id, refreshCount: navigator.refreshCount)) { await prefetch() }
    }

    private struct Key: Hashable {
        var appID: StoreApp.ID?
        var refreshCount: Int
    }

    private func prefetch() async {
        guard let app else { return }
        let warmer = WorkspaceSectionWarmer(
            services: services, queue: changes, summaries: summaries, push: push, suggestions: suggestions, preferences: preferences,
            modes: pricingModes, navigator: navigator, history: history, reviews: reviews, events: events, productPages: productPages,
            analytics: analytics, artwork: artwork, sellerName: session?.currentKeyID.flatMap { session?.teamNames[$0] },
            keyID: session?.currentKeyID, isPro: !pro.isFree,
            quota: { [keyID] in keyID.flatMap { AppStoreConnectQuota.shared.rateLimit(keyID: $0) } }
        )
        await SectionPrefetcher(models: sectionModels).prefetch(
            app,
            refreshCount: navigator.refreshCount,
            using: warmer,
            shown: { navigator.section },
            quota: { [keyID] in keyID.flatMap { AppStoreConnectQuota.shared.rateLimit(keyID: $0) } }
        )
    }
}
