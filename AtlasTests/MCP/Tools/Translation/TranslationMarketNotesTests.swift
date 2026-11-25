//
//  TranslationMarketNotesTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// Each language's agent learns its market's own variant, and what the
/// keywords' 100 bytes hold in its script.
@Suite("TranslationMarketNotes")
struct TranslationMarketNotesTests {
    @Test(arguments: StoreLocaleCatalog.all)
    func everyLocaleHasANote(_ locale: StoreLocale) {
        #expect(!TranslationMarketNotes.note(for: locale).isEmpty)
        #expect(TranslationMarketNotes.keywordRules(for: locale).contains("100 bytes"))
    }

    @Test func portugueseVariantsDontMixVocabulary() {
        let brazil = TranslationMarketNotes.note(for: .portugueseBrazil)
        let portugal = TranslationMarketNotes.note(for: .portuguesePortugal)
        #expect(brazil.contains("celular") && brazil.contains("você"))
        #expect(portugal.contains("telemóvel") && portugal.contains("ecrã"))
        #expect(portugal.contains("Never Brazilian forms"))
        #expect(brazil.contains("Never European forms"))
    }

    @Test func spanishVariantsDiffer() {
        #expect(TranslationMarketNotes.note(for: .spanishMexico).contains("never vosotros"))
        #expect(TranslationMarketNotes.note(for: .spanishSpain).contains("vosotros"))
        #expect(TranslationMarketNotes.note(for: .spanishMexico).contains("celular"))
        #expect(TranslationMarketNotes.note(for: .spanishSpain).contains("móvil"))
    }

    @Test func chineseScriptsAreWrittenNotConverted() {
        #expect(TranslationMarketNotes.note(for: .chineseSimplified).contains("mainland"))
        let traditional = TranslationMarketNotes.note(for: .chineseTraditional)
        #expect(traditional.contains("Taiwan"))
        #expect(traditional.contains("don't convert Simplified Chinese"))
    }

    @Test func keywordBytesFollowTheScript() {
        #expect(TranslationMarketNotes.bytesPerLetter(.german) == 1)
        #expect(TranslationMarketNotes.bytesPerLetter(.russian) == 2)
        #expect(TranslationMarketNotes.bytesPerLetter(.hebrew) == 2)
        #expect(TranslationMarketNotes.bytesPerLetter(.japanese) == 3)
        #expect(TranslationMarketNotes.bytesPerLetter(.korean) == 3)
        #expect(TranslationMarketNotes.keywordRules(for: .japanese).contains("about 33 characters fit"))
        #expect(TranslationMarketNotes.keywordRules(for: .ukrainian).contains("about 50 letters fit"))
        #expect(TranslationMarketNotes.keywordRules(for: .german).contains("no space after a comma"))
    }
}
