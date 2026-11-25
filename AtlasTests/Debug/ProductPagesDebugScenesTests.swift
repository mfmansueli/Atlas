//
//  ProductPagesDebugScenesTests.swift
//  AtlasTests
//

#if DEBUG
import Testing
@testable import Atlas

/// The Custom Product Pages DEBUG scenes resolve and open what they say.
@MainActor
@Suite("ProductPagesDebugScenes", .serialized)
struct ProductPagesDebugScenesTests {
    typealias PageID = DebugProductPagesData.PageID

    @Test(arguments: ProductPagesDebugScenes.ids)
    func everySceneResolves(_ id: String) {
        // Another area's "-s" scene, opened by a suite running alongside,
        // may have left the sidebar hidden.
        NavigationDebugLaunch.hidesSidebar = false
        #expect(ProductPagesDebugScenes.view(for: id) != nil)
        #expect(NavigationDebugLaunch.hidesSidebar == id.hasSuffix("-s"))
        ProductPagesDebugLaunch.pending = nil
        AnalyticsDebugLaunch.pending = nil
        NavigationDebugLaunch.hidesSidebar = false
    }

    @Test func unknownIDsAreLeftToOtherAreas() {
        #expect(ProductPagesDebugScenes.view(for: "overview") == nil)
        #expect(ProductPagesDebugScenes.view(for: "cp-unknown") == nil)
    }

    /// cp-submit: Private diary as if pushed, with Submit for Review open.
    @Test func theSubmitSceneOpensThePushedPage() async {
        _ = ProductPagesDebugScenes.view(for: "cp-submit")
        let launch = ProductPagesDebugLaunch.pending
        ProductPagesDebugLaunch.pending = nil
        let queue = ChangeQueue(changes: DebugProductPagesData.pendingChanges)
        let model = ProductPagesViewModel(
            app: DebugFixtures.lumen, services: DebugProductPagesServices(), store: DebugProductPagesData.store(), queue: queue
        )
        await model.load()
        launch?.apply(to: model)
        #expect(model.selectedPageID == PageID.privateDiaryPushed)
        #expect(model.isSubmitPresented)
        #expect(model.page(PageID.privateDiary) == nil)
        #expect(queue.changes.isEmpty)
    }
}
#endif
