//
//  AssistantTextLimitsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The house limits for what an assistant writes on a card (README-DS §9):
/// each refusal names the field, its count, the limit and what to do.
@Suite("Assistant text limits")
struct AssistantTextLimitsTests {
    private func text(_ count: Int) -> String {
        String(repeating: "x", count: count)
    }

    @Test func theLimitsAreTheReadmes() {
        #expect(AssistantTextLimits.titleWords == 8)
        #expect(AssistantTextLimits.titleCharacters == 60)
        #expect(AssistantTextLimits.why == 110)
        #expect(AssistantTextLimits.details == 400)
        #expect(AssistantTextLimits.gloss == 110)
        #expect(AssistantTextLimits.confidence == 1...3)
    }

    @Test func aWhyOverItsLimitSaysToMoveTheRestToDetails() {
        #expect(AssistantTextLimits.whyRefusal(text(110), field: "why") == nil)
        #expect(AssistantTextLimits.whyRefusal(text(164), field: "why") == "why is 164 characters; at most 110. Move the rest to details.")
        #expect(
            AssistantTextLimits.whyRefusal(text(111), field: "items[2].reason")
                == "items[2].reason is 111 characters; at most 110. Move the rest to details."
        )
    }

    @Test func aWhyWithoutDetailsBesideItSaysToKeepOneSentence() {
        #expect(
            AssistantTextLimits.whyRefusal(text(120), field: "reason", hasDetails: false)
                == "reason is 120 characters; at most 110. Keep one sentence."
        )
    }

    @Test func spacesAroundAWhyDontCount() {
        #expect(AssistantTextLimits.whyRefusal("  " + text(110) + "\n", field: "why") == nil)
    }

    @Test func detailsAndGlossHaveTheirOwnLimits() {
        #expect(AssistantTextLimits.detailsRefusal(text(400), field: "details") == nil)
        #expect(
            AssistantTextLimits.detailsRefusal(text(401), field: "details")
                == "details is 401 characters; at most 400. Keep the numbers that decide it."
        )
        #expect(AssistantTextLimits.glossRefusal(text(110), field: "gloss") == nil)
        #expect(
            AssistantTextLimits.glossRefusal(text(130), field: "gloss")
                == "gloss is 130 characters; at most 110. Say what it means, not word for word."
        )
    }

    @Test func aTitleIsAtMostEightWordsAndSixtyCharacters() {
        #expect(AssistantTextLimits.titleRefusal("Lifetime: $79.99 → $59.99", field: "title") == nil)
        #expect(
            AssistantTextLimits.titleRefusal("Japan opens the store page far less often than the others", field: "title")
                == "title has 11 words; at most 8. Move the rest to why or details."
        )
        #expect(
            AssistantTextLimits.titleRefusal(text(61), field: "title")
                == "title is 61 characters; at most 60. Move the rest to why or details."
        )
        #expect(AssistantTextLimits.titleRefusal("  ", field: "title") == "title is empty: say what changes or what you saw.")
    }

    @Test func confidenceIsOneToThree() {
        for value in 1...3 {
            #expect(AssistantTextLimits.confidenceRefusal(.int(value), field: "confidence") == nil)
        }
        #expect(AssistantTextLimits.confidenceRefusal(.null, field: "confidence") == nil)
        #expect(
            AssistantTextLimits.confidenceRefusal(.int(5), field: "confidence")
                == "confidence is 5; send 1 (not very sure), 2 (fairly sure) or 3 (sure)."
        )
        #expect(AssistantTextLimits.confidenceRefusal(.string("high"), field: "confidence")?.hasPrefix("confidence is \"high\"") == true)
    }

    @Test func wordsAreSplitOnWhitespace() {
        #expect(AssistantTextLimits.wordCount("Trial → paid fell to 21%") == 6)
        #expect(AssistantTextLimits.wordCount(" one\ttwo\nthree ") == 3)
    }
}
