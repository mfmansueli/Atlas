//
//  SuggestAllPrivacyPromptTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Suggest Everything drafts App Privacy too, as fill_privacy_from_code
/// does, and says the label is entered in App Store Connect by hand.
@MainActor
@Suite("suggest_all · App Privacy")
struct SuggestAllPrivacyPromptTests {
    private var text: String {
        MCPPrompt.suggestAll.message(app: "Lumen Journal")["messages"]?.arrayValue?.first?["content"]?["text"]?.stringValue ?? ""
    }

    @Test func suggestAllDraftsAppPrivacyFromTheProject() {
        #expect(text.contains("get_privacy_questionnaire"))
        #expect(text.contains("propose_privacy_answers"))
        #expect(text.contains("PrivacyInfo.xcprivacy"))
        #expect(text.contains("no API for App Privacy"))
    }

    @Test func thePrivacyToolsAreServed() {
        let names = MCPToolbox.standard.toolNames
        #expect(names.contains("get_privacy_questionnaire"))
        #expect(names.contains("propose_privacy_answers"))
    }
}
