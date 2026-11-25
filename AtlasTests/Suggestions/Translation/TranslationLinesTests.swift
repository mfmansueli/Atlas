//
//  TranslationLinesTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// Board 77: which lines a suggestion's card shows, by language and field.
@Suite("Translation lines")
struct TranslationLinesTests {
    @Test func anotherLanguageGetsMeansAndSounds() {
        #expect(TranslationLines.lines(locale: "de-DE", kind: .text, interfaceLanguage: "en") == .meansAndSounds)
        #expect(TranslationLines.lines(locale: "ja", kind: .text, interfaceLanguage: "en") == .meansAndSounds)
    }

    @Test func keywordsGetMeansOnly() {
        let lines = TranslationLines.lines(locale: "de-DE", kind: .keywords, interfaceLanguage: "en")
        #expect(lines == .meansOnly)
        #expect(lines.showsMeans)
        #expect(!lines.showsSounds)
    }

    @Test func urlsAndPickedAnswersGetNothing() {
        #expect(TranslationLines.lines(locale: "de-DE", kind: .url, interfaceLanguage: "en") == .none)
        #expect(TranslationLines.lines(locale: nil, kind: .choice, interfaceLanguage: "en") == .none)
    }

    @Test func theInterfaceLanguageGetsNothing() {
        #expect(TranslationLines.lines(locale: "en-US", kind: .text, interfaceLanguage: "en") == .none)
        #expect(TranslationLines.lines(locale: "en-GB", kind: .text, interfaceLanguage: "en") == .none)
        #expect(TranslationLines.lines(locale: "pt-BR", kind: .text, interfaceLanguage: "pt-BR") == .none)
        // With Atlas in Portuguese, English is another language.
        #expect(TranslationLines.lines(locale: "en-US", kind: .text, interfaceLanguage: "pt-BR") == .meansAndSounds)
    }

    @Test func aTextWithoutALanguageKeepsItsMeans() {
        #expect(TranslationLines.lines(locale: nil, kind: .text, interfaceLanguage: "en") == .meansOnly)
    }

    @Test func fieldSuggestionsKnowTheirKind() {
        func suggestion(_ target: SuggestionTarget) -> FieldSuggestion {
            FieldSuggestion(id: "sg_1", appID: "1", target: target, value: "x", reason: "Why.", source: .assistant(client: "Claude Code"))
        }
        #expect(suggestion(.storePage(.german, .whatsNew)).translationLines(interfaceLanguage: "en") == .meansAndSounds)
        #expect(suggestion(.storePage(.german, .keywords)).translationLines(interfaceLanguage: "en") == .meansOnly)
        #expect(suggestion(.storePage(.german, .supportURL)).translationLines(interfaceLanguage: "en") == .none)
        #expect(suggestion(.storePage(.englishUS, .subtitle)).translationLines(interfaceLanguage: "en") == .none)
        #expect(suggestion(.appInformation(.copyright)).translationLines(interfaceLanguage: "en") == .meansOnly)
    }

    @Test func languagesCompareByLanguageCode() {
        #expect(InterfaceLanguage.isSameLanguage("en-US", "en"))
        #expect(InterfaceLanguage.isSameLanguage("es-MX", "es-ES"))
        #expect(!InterfaceLanguage.isSameLanguage("pt-BR", "en"))
    }
}
