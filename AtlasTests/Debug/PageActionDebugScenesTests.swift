//
//  PageActionDebugScenesTests.swift
//  AtlasTests
//

#if DEBUG
import Testing
@testable import Atlas

/// Board 80's page action scenes resolve under the canvas's ids.
@MainActor
@Suite("PageActionDebugScenes")
struct PageActionDebugScenesTests {
    @Test(arguments: PageActionDebugScenes.ids)
    func everySceneResolves(_ id: String) {
        #expect(PageActionDebugScenes.view(for: id) != nil)
        #expect(DebugScene.requestedID(in: ["Atlas", "-AtlasDebugScene", id]) == id)
    }

    @Test func theyAreTheBoardsRows() {
        #expect(PageActionDebugScenes.ids == ["bar-pages", "bar-events", "bar-pricing", "bar-ft", "bar-shots"])
    }
}
#endif
