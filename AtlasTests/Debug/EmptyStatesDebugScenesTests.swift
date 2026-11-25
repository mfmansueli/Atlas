//
//  EmptyStatesDebugScenesTests.swift
//  AtlasTests
//

#if DEBUG
import Testing
@testable import Atlas

/// Board 74's DEBUG scenes resolve under the canvas's ids.
@MainActor
@Suite("EmptyStatesDebugScenes")
struct EmptyStatesDebugScenesTests {
    @Test(arguments: EmptyStatesDebugScenes.ids)
    func everySceneResolves(_ id: String) {
        #expect(EmptyStatesDebugScenes.view(for: id) != nil)
    }

    @Test func theCanvasIdsLeadToTheSectionsScenes() {
        #expect(DebugScene.requestedID(in: ["Atlas", "-AtlasDebugScene", "es-ev"]) == "ev-empty")
        #expect(DebugScene.requestedID(in: ["Atlas", "-AtlasDebugScene", "es-rv"]) == "rv-empty")
        #expect(DebugScene.requestedID(in: ["Atlas", "-AtlasDebugScene", "es-an"]) == "an-waiting")
        #expect(DebugScene.requestedID(in: ["Atlas", "-AtlasDebugScene", "es-rp"]) == "review-empty")
        #expect(DebugScene.requestedID(in: ["Atlas", "-AtlasDebugScene", "es-sh"]) == "es-sh")
    }
}
#endif
