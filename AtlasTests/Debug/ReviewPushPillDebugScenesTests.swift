//
//  ReviewPushPillDebugScenesTests.swift
//  AtlasTests
//

#if DEBUG
import Testing
@testable import Atlas

/// Board 80's Review & Push scenes open a view, under the prototype's ids.
@MainActor
@Suite("ReviewPushPillDebugScenes")
struct ReviewPushPillDebugScenesTests {
    @Test(arguments: ReviewPushPillDebugScenes.ids)
    func everySceneHasAView(id: String) {
        #expect(ReviewPushPillDebugScenes.view(for: id) != nil)
    }

    @Test func theBoardsScenesAreThere() {
        #expect(Set(["bar-pend", "bar-fly", "bar-push"]).isSubset(of: Set(ReviewPushPillDebugScenes.ids)))
        #expect(ReviewPushPillDebugScenes.view(for: "bar-idle") == nil, "The Autopilot bar's scenes are its own")
    }

    @Test func pendingHasGermanWhatsNewAndKeywords() {
        #expect(ReviewPushPillDebugScenes.whatsNew.title == "German · What’s New")
        #expect(ReviewPushPillDebugScenes.keywords.source == .builtInSuggestion)
    }
}
#endif
