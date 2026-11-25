//
//  ProductPagesPushDebugScenesTests.swift
//  AtlasTests
//

#if DEBUG
import Testing
@testable import Atlas

/// The board's page push scenes open Private diary with Review & Push on
/// it, as Push and Submit… does (README-Built §2).
@MainActor
@Suite("ProductPagesPushDebugScenes", .serialized)
struct ProductPagesPushDebugScenesTests {
    @Test(arguments: ProductPagesPushDebugScenes.ids)
    func everyPushSceneOpensReviewAndPushOnThePage(id: String) {
        defer {
            ProductPagesDebugLaunch.pending = nil
            NavigationDebugLaunch.hidesSidebar = false
        }
        #expect(ProductPagesDebugScenes.view(for: id) != nil)
        #expect(ProductPagesDebugLaunch.pending?.pageID == DebugProductPagesData.PageID.privateDiary)
        #expect(ProductPagesDebugLaunch.pending?.opensReview == true)
    }

    @Test func theBoardsSceneIDsAreAllThere() {
        for id in ["cp-push", "cp-pushing", "cp-push-partial", "cp-push-done", "cp-push-s", "cp-shots-s"] {
            #expect(ProductPagesDebugScenes.ids.contains(id), "\(id)")
        }
        #expect(Set(ProductPagesDebugScenes.ids).count == ProductPagesDebugScenes.ids.count)
    }

    @Test func theNarrowScenesHideTheSidebar() {
        defer {
            ProductPagesDebugLaunch.pending = nil
            NavigationDebugLaunch.hidesSidebar = false
        }
        for id in ["cp-push-s", "cp-shots-s"] {
            NavigationDebugLaunch.hidesSidebar = false
            _ = ProductPagesDebugScenes.view(for: id)
            #expect(NavigationDebugLaunch.hidesSidebar, "\(id)")
        }
        _ = ProductPagesDebugScenes.view(for: "cp-shots-s")
        #expect(ProductPagesDebugLaunch.pending?.pageShots == .result)
    }

    /// Only the keyword writes after the page's create are refused, so the
    /// page itself goes and the row names the step.
    @Test func thePartialPushRefusesTheKeywordsOnly() {
        let keys = Array(ProductPagesPushDebugScenes.partialFailures.keys)
        #expect(keys == ["searchKeywords"])
    }
}
#endif
