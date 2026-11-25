//
//  AssistantTranslatePromptTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

@Suite("AssistantTranslatePrompt")
struct AssistantTranslatePromptTests {
    @Test func theSlashCommandNamesTheApp() {
        let prompt = AssistantTranslatePrompt(appName: "Lumen Journal", versionString: "1.4", glossary: TranslationGlossary())
        #expect(prompt.slashCommand == "/mcp__atlas__translate_missing Lumen Journal")
    }

    @Test func theTextCarriesTheGlossaryAndTone() {
        let glossary = TranslationGlossary(terms: ["Lumen", "Face ID"], tone: .warmAndSimple)
        let prompt = AssistantTranslatePrompt(appName: "Lumen Journal", versionString: "1.4", glossary: glossary)
        #expect(prompt.text.hasPrefix("Translate the Store Page of Lumen Journal 1.4 with Atlas, one native-speaker agent per language"))
        #expect(prompt.text.hasSuffix("Keep “Lumen” and “Face ID” untranslated and keep the tone warm and simple."))
        // Without languages, the assistant finds the empty ones.
        #expect(prompt.text.contains("list_missing_translations"))
    }

    @Test func withoutTermsOnlyTheToneIsAsked() {
        let prompt = AssistantTranslatePrompt(appName: "Tempo", versionString: "3.0", glossary: TranslationGlossary(terms: [], tone: .playful))
        #expect(prompt.text.hasSuffix("Keep the tone playful."))
        #expect(!prompt.text.contains("untranslated"))
    }
}
