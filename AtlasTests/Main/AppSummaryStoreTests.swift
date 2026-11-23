//
//  AppSummaryStoreTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@MainActor
@Suite("AppSummaryStore")
struct AppSummaryStoreTests {
    private let lumen = StoreApp(id: DebugFixtures.AppID.lumen, name: "Lumen", bundleID: "com.northpier.lumen")
    private let pricing = CountingPricingServices()

    private func makeStore() -> AppSummaryStore {
        var services = WorkspaceServices.debug
        services.pricing = pricing
        return AppSummaryStore(services: services)
    }

    @Test func loadsAllThreeSummariesOnce() async {
        let store = makeStore()
        await store.load(lumen)
        await store.load(lumen)
        #expect(pricing.fetches == 1)
        #expect(store.pricing[lumen.id] == .loaded(.empty))
        #expect(store.storePage[lumen.id]?.value == DebugSummaries.storePage(for: lumen.id))
        #expect(store.appInformation[lumen.id]?.value != nil)
    }

    @Test func forceAndInvalidateFetchAgain() async {
        let store = makeStore()
        await store.load(lumen)
        await store.load(lumen, force: true)
        #expect(pricing.fetches == 2)
        store.invalidate(lumen.id)
        #expect(store.pricing[lumen.id] == nil)
        await store.load(lumen)
        #expect(pricing.fetches == 3)
    }

    @Test func failuresShowTheErrorAndRetryOnTheNextLoad() async {
        let store = makeStore()
        pricing.error = AppStoreConnectError.rateLimited
        await store.load(lumen)
        #expect(store.pricing[lumen.id]?.errorMessage == "Prices didn’t load. Apple’s hourly limit was reached. Try again in a few minutes.\nDetails: HTTP 429")
        pricing.error = nil
        await store.load(lumen)
        #expect(store.pricing[lumen.id]?.value == .empty)
        #expect(pricing.fetches == 2)
    }

    @Test func appIsSettledOnceEverySummaryLoadedOrFailed() async {
        let store = makeStore()
        #expect(!store.isSettled(lumen.id))
        pricing.error = AppStoreConnectError.rateLimited
        await store.load(lumen)
        #expect(store.isSettled(lumen.id))
        store.invalidate(lumen.id)
        #expect(!store.isSettled(lumen.id))
    }
}
