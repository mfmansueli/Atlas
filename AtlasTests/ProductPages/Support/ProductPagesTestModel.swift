//
//  ProductPagesTestModel.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Lumen Journal's Custom Product Pages, read: five pages in App Store
/// Connect, Private diary made in Atlas and two suggested pages.
@MainActor
enum ProductPagesTestModel {
    typealias Sample = DebugProductPagesData

    static func make(
        _ services: FakeProductPagesServices = FakeProductPagesServices(),
        store: ProductPagesStore = Sample.store(),
        queue: ChangeQueue = ChangeQueue(changes: Sample.pendingChanges)
    ) async -> ProductPagesViewModel {
        let model = ProductPagesViewModel(app: DebugFixtures.lumen, services: services, store: store, queue: queue)
        model.now = { Sample.now }
        await model.load()
        return model
    }

    static func page(_ model: ProductPagesViewModel, _ id: ProductPage.ID) throws -> ProductPage {
        guard let page = model.page(id) else { throw ProductPagesTestError.noPage(id) }
        return page
    }
}
