//
//  SettingsPaneTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// Settings' panes (board 48): what each says and what finds it.
@Suite("Settings panes")
struct SettingsPaneTests {
    @Test func everyPaneHasItsWords() {
        for pane in SettingsPane.allCases {
            #expect(!pane.title.isEmpty, "\(pane)")
            #expect(!pane.subtitle.isEmpty, "\(pane)")
            #expect(!pane.systemImage.isEmpty, "\(pane)")
        }
    }

    @Test func theDesignsOrder() {
        #expect(SettingsPane.allCases.map(\.title) == [
            "General", "Accounts", "AI Assistants", "Suggestions", "Pricing", "Screenshots", "Notifications", "Atlas Pro", "Privacy & Data",
        ])
    }

    @Test func searchFindsAPaneByItsTitleOrWhatsInIt() {
        #expect(SettingsPane.accounts.matches("account"))
        #expect(SettingsPane.accounts.matches("vendor"))
        #expect(SettingsPane.assistants.matches("MCP"))
        #expect(SettingsPane.notifications.matches("dock"))
        #expect(SettingsPane.screenshots.matches("artwork"))
        #expect(!SettingsPane.pricing.matches("keychain"))
        // An empty search shows every pane.
        #expect(SettingsPane.privacy.matches(""))
    }

    @Test func theSourcesUseTheDesignsWords() {
        #expect(TranslationProvider.assistant.sourceTitle == "Your assistant")
        #expect(TranslationProvider.aiProvider.sourceTitle == "An API key")
        #expect(TranslationProvider.appleTranslation.sourceTitle == "Built-in only")
        #expect(TranslationProvider.aiProvider.sourceDetail.hasPrefix("Atlas asks the provider directly"))
    }

    @Test func confirmationsCaptionCountsWhatsOff() {
        #expect(PrivacySettingsPane.confirmationsCaption(0) == "Every confirmation is on.")
        #expect(PrivacySettingsPane.confirmationsCaption(1) == "1 confirmation is turned off.")
        #expect(PrivacySettingsPane.confirmationsCaption(3) == "3 confirmations are turned off.")
    }
}
