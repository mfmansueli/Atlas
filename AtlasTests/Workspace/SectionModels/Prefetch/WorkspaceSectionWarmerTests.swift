//
//  WorkspaceSectionWarmerTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@MainActor
@Suite("WorkspaceSectionWarmer")
struct WorkspaceSectionWarmerTests {
    private let app = DebugFixtures.lumen

    private func warmer(_ services: WorkspaceServices = .debug) -> WorkspaceSectionWarmer {
        let queue = ChangeQueue()
        let history = PushHistory()
        return WorkspaceSectionWarmer(
            services: services,
            queue: queue,
            summaries: AppSummaryStore(services: services),
            push: PushController(queue: queue, history: history, transport: services.push, secrets: services.appInformation.secrets),
            suggestions: FieldSuggestionStore(),
            preferences: AppPreferences(defaults: nil),
            modes: PricingModeStore(defaults: nil, modes: [app.id: .showSuggestions]),
            navigator: WorkspaceNavigator(),
            history: history,
            reviews: ReviewsStore(),
            events: InAppEventsStore(),
            productPages: ProductPagesStore(),
            analytics: AnalyticsStore(),
            artwork: EventArtworkStudio(),
            sellerName: "Northpier",
            keyID: nil,
            isPro: true
        )
    }

    private func kept() -> AppSectionModels {
        WorkspaceSectionModels().models(for: app.id)
    }

    /// Warms `section` and says whether it still needs it afterwards.
    private func warm(_ section: AppWorkspaceSection, with warmer: WorkspaceSectionWarmer, kept: AppSectionModels, refreshCount: Int = 0) async -> Bool {
        #expect(warmer.needsWarming(section, of: app, kept: kept, refreshCount: refreshCount))
        await warmer.warm(section, of: app, kept: kept, refreshCount: refreshCount)
        return warmer.needsWarming(section, of: app, kept: kept, refreshCount: refreshCount)
    }

    @Test func theStorePageIsLeftLoadedAsTheSectionMakesIt() async {
        let warmer = warmer()
        let kept = kept()
        #expect(await !warm(.storePage, with: warmer, kept: kept))
        #expect(kept.storePage?.isLoaded == true)
        #expect(kept.storePage?.checksRepeatedWords == warmer.preferences.checksRepeatedWords)
    }

    @Test func aLoadedPageIsReadAgainAfterRefreshNotMadeAnew() async {
        let warmer = warmer()
        let kept = kept()
        _ = await warm(.storePage, with: warmer, kept: kept)
        let first = kept.storePage
        #expect(await !warm(.storePage, with: warmer, kept: kept, refreshCount: 1))
        #expect(kept.storePage === first)
    }

    @Test func aPageThatFailsToReadIsntStamped() async {
        var services = WorkspaceServices.debug
        var storePage = DebugStorePageServices()
        storePage.error = .unexpectedPayload
        services.storePage = storePage
        let warmer = warmer(services)
        let kept = kept()
        #expect(await warm(.storePage, with: warmer, kept: kept), "Tried again the next time")
        #expect(kept.storePage?.isLoaded == false)
    }

    @Test func overviewKeepsThePageItsPreviewDraws() async {
        let kept = kept()
        #expect(await !warm(.overview, with: warmer(), kept: kept))
        #expect(kept.overviewContent?.appName == app.name)
    }

    @Test func appInformationIsLoadedWithTheTeamsName() async {
        let kept = kept()
        #expect(await !warm(.appInformation, with: warmer(), kept: kept))
        #expect(kept.appInformation?.isLoaded == true)
        #expect(kept.appInformation?.sellerName == "Northpier")
    }

    @Test func pricingKeepsThePricesAndRetentionBesideThem() async {
        let kept = kept()
        #expect(await !warm(.subscriptionPricing, with: warmer(), kept: kept))
        #expect(kept.pricing?.catalog != nil)
        #expect(kept.retention != nil)
    }

    @Test func keptPricesAreReadAgainAfterRefresh() async {
        let warmer = warmer()
        let kept = kept()
        _ = await warm(.subscriptionPricing, with: warmer, kept: kept)
        let first = kept.pricing
        #expect(await !warm(.subscriptionPricing, with: warmer, kept: kept, refreshCount: 1))
        #expect(kept.pricing === first)
    }

    @Test func screenshotsReadTheSetsToo() async {
        let kept = kept()
        #expect(await !warm(.screenshots, with: warmer(), kept: kept))
        #expect(kept.screenshots?.screenshots?.isLoaded == true)
    }

    @Test func productPagesAreKeptAndStamped() async {
        let kept = kept()
        #expect(await !warm(.productPages, with: warmer(), kept: kept))
        #expect(kept.productPages?.state.value != nil)
    }

    @Test func eventsAreKeptLoaded() async {
        let kept = kept()
        #expect(await !warm(.inAppEvents, with: warmer(), kept: kept))
        #expect(kept.events?.state.value != nil)
        #expect(kept.events?.artworkStudio != nil)
    }

    /// After a push (or Refresh) the kept events are read again, into the
    /// same model: dates pushed off screen show when In-App Events opens.
    @Test func keptEventsAreReadAgainAfterAPush() async throws {
        let asc = FakeInAppEventsServices([DebugInAppEventsData.mood])
        var services = WorkspaceServices.debug
        services.inAppEvents = asc
        let warmer = warmer(services)
        let kept = kept()
        _ = await warm(.inAppEvents, with: warmer, kept: kept)
        let first = try #require(kept.events)
        #expect(!warmer.needsWarming(.inAppEvents, of: app, kept: kept, refreshCount: 0))

        var moved = DebugInAppEventsData.mood
        moved.schedules[0].publishStart = moved.schedules[0].publishStart?.addingTimeInterval(86400)
        asc.events = [moved]
        #expect(await !warm(.inAppEvents, with: warmer, kept: kept, refreshCount: 1))
        #expect(kept.events === first)
        #expect(first.events.first?.dates == moved.dates)
    }

    @Test func reviewsAreReadIntoTheStore() async {
        let kept = kept()
        #expect(await !warm(.reviews, with: warmer(), kept: kept))
        #expect(kept.reviews?.isPro == true)
    }

    @Test func analyticsKeepsWhatTheOtherSectionsKnow() async {
        let kept = kept()
        #expect(await !warm(.analytics, with: warmer(), kept: kept))
        #expect(kept.analytics != nil)
    }
}
