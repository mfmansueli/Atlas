//
//  DesignSceneAliasesTests.swift
//  AtlasTests
//

#if DEBUG
import Testing
@testable import Atlas

/// The canvas's scene names for states Atlas draws under another id.
@MainActor
@Suite("DesignSceneAliases")
struct DesignSceneAliasesTests {
    @Test func theLaunchArgumentTakesTheCanvassName() {
        #expect(DebugScene.requestedID(in: ["Atlas", "-AtlasDebugScene", "mb-closed"]) == "mb-note")
        #expect(DebugScene.requestedID(in: ["Atlas", "-AtlasDebugScene", "addkey-err"]) == "addkey-403")
        #expect(DebugScene.requestedID(in: ["Atlas", "-AtlasDebugScene", "sp-cc"]) == "sp-cc", "Other ids stay as they are")
    }

    @Test func everyAliasLeadsToASceneAtlasHas() {
        let known = Set(
            ConnectDebugScenes.ids + SettingsDebugScenes.ids + HelpDebugScenes.ids + MenuBarDebugScenes.ids
                + PaywallDebugScenes.ids + InAppEventsDebugScenes.ids + ReviewsDebugScenes.ids + ReviewPushDebugScenes.ids
                + EmptyStatesDebugScenes.ids + ["an-waiting"]
        )
        for (alias, target) in DesignSceneAliases.aliases {
            #expect(known.contains(target), "\(alias) → \(target)")
            #expect(!known.contains(alias), "\(alias) would hide a scene of its own")
        }
    }
}
#endif
