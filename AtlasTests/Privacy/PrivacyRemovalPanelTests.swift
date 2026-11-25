//
//  PrivacyRemovalPanelTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// "Remove All Keys and Data…" asked in place (README-DS §9, risk level 4):
/// the panel names what goes and what stays.
@MainActor
@Suite("Privacy removal panel")
struct PrivacyRemovalPanelTests {
    @Test func itNamesWhatGoes() {
        let detail = PrivacyRemovalPanel.detail
        for what in ["App Store Connect key", "API key", "paired assistant", "unpushed draft", "suggestion"] {
            #expect(detail.contains(what), "\(what)")
        }
        #expect(detail.contains("Atlas quits."))
        #expect(detail.contains("Nothing changes in App Store Connect."))
        #expect(PrivacyRemovalPanel.title == "Remove all keys and data from this Mac?")
    }

    @Test func theSceneAsksInPlace() {
        #expect(SettingsDebugScenes.pane(for: "set-privacy-remove") == .privacy)
        #expect(SettingsDebugScenes.confirmsRemovingEverything("set-privacy-remove"))
        #expect(!SettingsDebugScenes.confirmsRemovingEverything("set-privacy"))
    }
}
