//
//  NativeTranslationDebugScenesTests.swift
//  AtlasTests
//

#if DEBUG
import Testing
@testable import Atlas

/// The native translation scenes resolve, and their run is counted by
/// language: one of four while it works, finished once the last ends.
@MainActor
@Suite("NativeTranslationDebugScenes")
struct NativeTranslationDebugScenesTests {
    @Test(arguments: NativeTranslationDebugScenes.ids)
    func everySceneResolves(_ id: String) {
        #expect(NativeTranslationDebugScenes.view(for: id) != nil)
    }

    @Test func idsDontClashWithTheOtherBoards() {
        let others = SuggestionsDebugScenes.ids + AssistDebugScenes.ids + EverythingDebugScenes.ids + NewLanguagesDebugScenes.ids
        #expect(Set(NativeTranslationDebugScenes.ids).isDisjoint(with: others))
    }

    @Test func theRunCountsLanguages() throws {
        let working = try #require(NativeTranslationDebugData.store(.working).run)
        #expect(working.progressText == "Translating · 1 of 4 languages")
        #expect(working.received == 4)
        #expect(working.isComing(.storePage(.japanese, .subtitle)))

        let store = NativeTranslationDebugData.store(.lastInReview)
        #expect(store.run?.progressText == "Translating · 3 of 4 languages")
        NativeTranslationDebugData.endLast(in: store)
        let finished = try #require(store.run)
        #expect(finished.phase == .finished)
        #expect(finished.finishedText == "Claude Code sent 8 suggestions in 4 languages.")
    }
}
#endif
