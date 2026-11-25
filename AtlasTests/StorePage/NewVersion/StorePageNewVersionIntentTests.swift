//
//  StorePageNewVersionIntentTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Create Version… from another section (Screenshots' banner with no
/// version to push to): the Store Page takes the intent and opens New
/// Version once it has loaded, only when a version can be made.
@MainActor
@Suite("Store Page new version intent")
struct StorePageNewVersionIntentTests {
    private let queue = ChangeQueue()

    private func makeModel(_ contents: [StorePageContent] = [StorePageContentFixtures.liveOnly]) async -> StorePageViewModel {
        let model = StorePageViewModel(app: StorePageContentFixtures.app, services: FakeStorePageServices(contents: contents), queue: queue)
        await model.load()
        return model
    }

    @Test func theStorePageTakesTheIntent() {
        #expect(StorePageViewModel.handles(.newVersion))
    }

    @Test func itOpensNewVersionWhenOnlyTheLiveVersionExists() async {
        let model = await makeModel()
        model.handle(.newVersion)
        #expect(model.sheet == .newVersion)
    }

    @Test func itWaitsForThePageToLoad() async {
        let model = StorePageViewModel(
            app: StorePageContentFixtures.app, services: FakeStorePageServices(contents: [StorePageContentFixtures.liveOnly]), queue: queue
        )
        model.handle(.newVersion)
        #expect(model.sheet == nil)
        await model.load()
        #expect(model.sheet == .newVersion)
    }

    @Test func aVersionInProgressOpensNothing() async {
        let model = await makeModel([StorePageContentFixtures.editable, StorePageContentFixtures.live])
        model.handle(.newVersion)
        #expect(model.sheet == nil)
    }
}
