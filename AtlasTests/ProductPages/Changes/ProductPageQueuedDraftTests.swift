//
//  ProductPageQueuedDraftTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A draft's create change queued by an older Atlas is made again from the
/// draft at the next read, so it sends what App Store Connect takes now.
@MainActor
struct ProductPageQueuedDraftTests {
    typealias Sample = DebugProductPagesData

    @Test func anOlderCreateRequestIsMadeAgainFromTheDraft() async throws {
        let store = Sample.store()
        let draft = Sample.privateDiary
        store.save(draft, for: DebugFixtures.lumen.id)
        let builder = ProductPageChangeBuilder(appID: DebugFixtures.lumen.id)
        var old = try #require(builder.newPageChange(draft, defaultPage: Sample.defaultPage))
        // What the first Atlas sent: the page and its version, no languages.
        old.requests = [PushRequest(method: .post, path: "/v1/appCustomProductPages", body: Data("{}".utf8))]
        let queue = ChangeQueue(changes: [old])

        let model = await ProductPagesTestModel.make(store: store, queue: queue)

        let made = try #require(queue.change(id: old.id))
        #expect(made.requests != old.requests)
        #expect(made.requests == model.builder.newPageChange(draft, defaultPage: model.defaultPage)?.requests)
    }
}
