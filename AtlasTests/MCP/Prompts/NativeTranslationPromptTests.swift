//
//  NativeTranslationPromptTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Every request for texts in several languages asks for one
/// native-speaker agent per language, with the cap, and the ones Atlas
/// builds in the app name the languages.
@Suite("Native translation prompts")
struct NativeTranslationPromptTests {
    private func text(_ prompt: MCPPrompt, app: String? = "Lumen Journal") -> String {
        prompt.message(app: app)["messages"]?.arrayValue?.first?["content"]?["text"]?.stringValue ?? ""
    }

    @Test func translateMissingStartsOneAgentPerLanguage() {
        let text = text(.translateMissing)
        #expect(text.contains("one native-speaker agent per language"))
        #expect(text.contains("Start one subagent per language with the Agent tool"))
        #expect(text.contains("at most \(NativeTranslationFlow.maxAgents) agents at a time"))
        #expect(text.contains("begin_translation"))
        #expect(text.contains("get_translation_brief"))
        #expect(text.contains("You coordinate and don't write the translations yourself"))
        #expect(text.contains("end_suggestions and its locale"))
        for field in NativeTranslationFlow.reviewFields {
            #expect(text.contains(field), "\(field)")
        }
    }

    @Test func translateCaptionsStartsOneAgentPerLanguage() {
        let text = text(.translateCaptions)
        #expect(text.contains("one native-speaker agent per language"))
        #expect(text.contains("fields [captions]"))
        #expect(text.contains("measure_caption"))
    }

    @Test func theTranslateSheetNamesItsLanguagesAndFields() {
        let prompt = AssistantTranslatePrompt(
            appName: "Lumen Journal", versionString: "1.4", glossary: TranslationGlossary(terms: ["Lumen"]),
            locales: [.german, .japanese, .portugueseBrazil], fields: [.keywords, .whatsNew]
        )
        #expect(prompt.text.hasPrefix(
            "Translate the Store Page of Lumen Journal 1.4 into German, Japanese, and Portuguese (Brazil) (de-DE, ja, pt-BR) with Atlas"
        ))
        #expect(prompt.text.contains("begin_translation once with the locales [de-DE, ja, pt-BR] and fields [keywords, whatsNew] with missingOnly true"))
        #expect(prompt.text.contains("Keep “Lumen” untranslated"))
        #expect(!prompt.text.contains("list_missing_translations"))
    }

    @Test func theCaptionSheetNamesItsLanguages() {
        let prompt = CaptionAssistantPrompt(appName: "Lumen Journal", versionString: "1.4", glossary: TranslationGlossary(), locales: [.french, .polish])
        #expect(prompt.text.contains("into French and Polish (fr-FR, pl)"))
        #expect(prompt.text.contains("the locales [fr-FR, pl] and fields [captions]"))
    }

    @Test func suggestEverythingAndAskHandOtherLanguagesToNativeAgents() {
        #expect(text(.suggestAll).contains("start one native-speaker subagent per language with the Agent tool"))
        #expect(text(.suggestAll).contains("get_translation_brief with the appId and its locale and the run"))
        let ask = MCPPrompt.suggest.message(app: "Lumen Journal", area: "store")["messages"]?.arrayValue?.first?["content"]?["text"]?.stringValue ?? ""
        #expect(ask.contains("get_translation_brief with the appId and its locale, to write its fields natively"))
        let info = MCPPrompt.suggest.message(app: "Lumen Journal", area: "info")["messages"]?.arrayValue?.first?["content"]?["text"]?.stringValue ?? ""
        #expect(!info.contains("Agent tool"))
    }

    @Test func whatsNewInOtherLanguagesGoesToNativeAgents() throws {
        let ask = try #require(WorkspaceAutopilotAsk.make(.writeWhatsNew, app: "Lumen Journal", version: "1.4"))
        #expect(ask.prompt.contains("begin_translation once with the locales and fields [whatsNew]"))
        let store = SuggestionPrompt.text(for: .storePage, app: "Lumen Journal", version: "1.4")
        #expect(store.contains("one native-speaker subagent per language"))
    }

    @Test func theServerTellsEveryAssistant() {
        #expect(MCPEndpoint.instructions.contains("call begin_translation and start one subagent per language"))
        #expect(MCPEndpoint.instructions.contains("at most \(NativeTranslationFlow.maxAgents) at a time"))
    }

    @Test func languageListsNameAndCodeEachLanguage() {
        #expect(NativeTranslationFlow.languageList([.german]) == "German (de-DE)")
        #expect(NativeTranslationFlow.languageList([.german, .chineseTraditional]).hasSuffix("(de-DE, zh-Hant)"))
    }
}
