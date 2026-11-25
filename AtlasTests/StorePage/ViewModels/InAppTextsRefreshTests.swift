//
//  InAppTextsRefreshTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Refresh (⌘R) keeps In-App Purchase texts on screen while they're read
/// again: only the first read shows the skeleton.
@MainActor
@Suite("InAppTextsViewModel refresh")
struct InAppTextsRefreshTests {
    private let product = InAppTextProduct(id: "lumen.monthly", referenceName: "Monthly", kind: .subscription)

    private var content: InAppTextsContent {
        InAppTextsContent(
            products: [product],
            texts: [.englishUS: ["lumen.monthly.name": "Lumen Plus Monthly"]],
            groupID: "grp",
            groupLocalizations: [:],
            productResourceIDs: ["lumen.monthly": "sub1"],
            productLocalizations: ["lumen.monthly": [.englishUS: "sl-en"]],
            editableVersions: ["lumen.monthly": "sv1"]
        )
    }

    @Test func theFirstReadShowsTheSkeleton() async {
        let services = FakeStorePageServices()
        services.inAppTextsContent = content
        let (stream, release) = AsyncStream<Void>.makeStream()
        services.beforeInAppTexts = { for await _ in stream { break } }
        let model = InAppTextsViewModel(app: StorePageContentFixtures.app, services: services, queue: ChangeQueue())

        let read = Task { await model.load(listing: StorePageContentFixtures.editable.listing()) }
        await Self.waitUntil { model.state.isLoading }
        #expect(model.state.isLoading)
        #expect(!model.isRefreshing)
        release.yield()
        release.finish()
        await read.value
        #expect(model.state.value != nil)
    }

    @Test func aRefreshKeepsTheTextsShown() async {
        let services = FakeStorePageServices()
        services.inAppTextsContent = content
        let model = InAppTextsViewModel(app: StorePageContentFixtures.app, services: services, queue: ChangeQueue())
        await model.load(listing: StorePageContentFixtures.editable.listing())
        #expect(model.matrix != nil)

        let (stream, release) = AsyncStream<Void>.makeStream()
        services.beforeInAppTexts = { for await _ in stream { break } }
        let refresh = Task { await model.load(listing: nil, force: true) }
        await Self.waitUntil { model.isRefreshing }
        #expect(model.isRefreshing)
        #expect(!model.state.isLoading, "no skeleton over texts already shown")
        #expect(model.state.value != nil)
        #expect(model.matrix != nil)

        // A second refresh while one runs doesn't start another read.
        await model.load(listing: nil, force: true)
        #expect(model.isRefreshing)

        release.yield()
        release.finish()
        await refresh.value
        #expect(!model.isRefreshing)
        #expect(model.state.value != nil)
    }

    /// Yields until `condition` holds, at most a few thousand times.
    private static func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<5000 where !condition() {
            await Task.yield()
        }
    }
}
