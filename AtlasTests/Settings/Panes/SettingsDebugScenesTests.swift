//
//  SettingsDebugScenesTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The Settings (board 48) and Help (board 49) DEBUG scenes.
@MainActor
@Suite("Settings and Help scenes")
struct SettingsDebugScenesTests {
    @Test(arguments: SettingsDebugScenes.ids)
    func everySettingsSceneOpensAPane(id: String) {
        #expect(SettingsDebugScenes.pane(for: id) != nil)
        #expect(SettingsDebugScenes.view(for: id) != nil)
    }

    @Test(arguments: HelpDebugScenes.ids)
    func everyHelpSceneHasAView(id: String) {
        #expect(HelpDebugScenes.view(for: id) != nil)
    }

    @Test func idsAreUnique() {
        let all = SettingsDebugScenes.ids + HelpDebugScenes.ids
        #expect(Set(all).count == all.count)
    }

    @Test func theDesignsScenes() {
        #expect(SettingsDebugScenes.pane(for: "set-shots") == .screenshots)
        #expect(SettingsDebugScenes.pane(for: "set-notif-blocked") == .notifications)
        #expect(SettingsDebugScenes.pane(for: "set-free") == .pro)
        #expect(SettingsDebugScenes.source(for: "set-assistants-key") == .aiProvider)
        #expect(SettingsDebugScenes.source(for: "set-assistants-none") == .appleTranslation)
        #expect(SettingsDebugScenes.source(for: "set-assistants") == .assistant)
        #expect(SettingsDebugScenes.removingKeyID(for: "set-accounts-remove") == DebugFixtures.brightline.keyID)
        #expect(SettingsDebugScenes.assistantsState(for: "set-assistants-off") == .off)
    }

    @Test func proScenes() {
        #expect(SettingsDebugScenes.proGate(for: "set-free")?.isFree == true)
        #expect(SettingsDebugScenes.proGate(for: "set-general") == nil)
    }
}
