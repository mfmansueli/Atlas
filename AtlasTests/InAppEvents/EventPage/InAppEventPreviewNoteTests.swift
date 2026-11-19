//
//  InAppEventPreviewNoteTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The line under the event's preview (board 40): the concept previewed,
/// whose text it is, and where the App Store shows it.
@Suite("In-App Event preview note")
struct InAppEventPreviewNoteTests {
    private func texts(_ locale: String, _ origin: InAppEventShownTexts.Origin) -> InAppEventShownTexts {
        InAppEventShownTexts(locale: locale, name: "N", shortDescription: "S", longDescription: "L", origin: origin, isRightToLeft: false)
    }

    private let english = InAppEventChangeBuilder.localeName("en-US")
    private let german = InAppEventChangeBuilder.localeName("de-DE")

    @Test func aConceptPreviewedIsSaidFirst() {
        let note = InAppEventPreviewNote.make(
            previewing: "A path of lights", texts: texts("en-US", .own), primaryLocale: "en-US", kind: .card, appName: "Lumen"
        )
        #expect(note.isPreviewing)
        #expect(note.text == "Previewing “A path of lights”, not chosen yet. Text in \(english). Search, Today and Lumen’s page.")
    }

    @Test func aSuggestionIsShownUntilAccepted() {
        let note = InAppEventPreviewNote.make(previewing: nil, texts: texts("de-DE", .suggestion), primaryLocale: "en-US", kind: .details, appName: "Lumen")
        #expect(!note.isPreviewing)
        #expect(note.text == "Text: the \(german) suggestion. Until you accept it, people there see \(english). The top of the event’s page.")
    }

    @Test func aLanguageWithoutTextShowsThePrimary() {
        let note = InAppEventPreviewNote.make(previewing: nil, texts: texts("de-DE", .fallback), primaryLocale: "en-US", kind: .card, appName: "Lumen")
        #expect(note.text == "No \(german) text yet, so people there see \(english). Search, Today and Lumen’s page.")
    }
}
