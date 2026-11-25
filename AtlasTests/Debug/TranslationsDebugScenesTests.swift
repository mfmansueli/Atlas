//
//  TranslationsDebugScenesTests.swift
//  AtlasTests
//

#if DEBUG
import Testing
@testable import Atlas

/// Board 77's DEBUG scenes resolve, don't clash with other boards' ids,
/// and their readings follow the MCP rules.
@MainActor
@Suite("TranslationsDebugScenes")
struct TranslationsDebugScenesTests {
    @Test(arguments: TranslationsDebugScenes.ids)
    func everySceneResolves(_ id: String) {
        #expect(TranslationsDebugScenes.view(for: id) != nil)
    }

    @Test func idsDontClashWithTheOtherBoards() {
        let others = SuggestionsDebugScenes.ids + NewLanguagesDebugScenes.ids + AssistDebugScenes.ids + EverythingDebugScenes.ids
        #expect(Set(TranslationsDebugScenes.ids).isDisjoint(with: others))
        #expect(TranslationsDebugScenes.view(for: "sp-unknown") == nil)
    }

    @Test func everyReadingFollowsTheRules() throws {
        let store = TranslationsDebugData.store()
        let read = store.open(for: DebugFixtures.AppID.lumen).compactMap(\.layers)
        #expect(read.contains { $0.translation?.sounds == .off })
        for layers in read {
            #expect(layers.translation?.problems().isEmpty ?? true)
            #expect((layers.means?.count ?? 0) <= AssistantTextLimits.means)
        }
        let subtitle = try #require(TranslationsDebugData.suggestion(.subtitle, in: .polish, of: store))
        #expect(subtitle.soundsOff(interfaceLanguage: "en"))
        #expect(MCPNaturalCheck.refusal(subtitle.layers, for: .subtitle) == nil)
    }
}
#endif
