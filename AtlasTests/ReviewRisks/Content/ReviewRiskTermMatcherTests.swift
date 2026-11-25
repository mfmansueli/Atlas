//
//  ReviewRiskTermMatcherTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Finding words for the content checks")
struct ReviewRiskTermMatcherTests {
    @Test func shortCapitalsMatchCapitalsOnly() {
        #expect(ReviewRiskTermMatcher.range(of: "AI", in: "Write with AI.") != nil)
        #expect(ReviewRiskTermMatcher.range(of: "AI", in: "Vai ai monti") == nil)
        #expect(ReviewRiskTermMatcher.range(of: "AI", in: "PAINT your SAIL") == nil)
        #expect(ReviewRiskTermMatcher.range(of: "AI", in: "AI-powered notes") != nil)
    }

    @Test func wordsMatchWhole() {
        #expect(ReviewRiskTermMatcher.range(of: "dating", in: "Dating for book lovers") != nil)
        #expect(ReviewRiskTermMatcher.range(of: "dating", in: "Accommodating every guest") == nil)
    }

    @Test func phrasesTakeAnySpaces() {
        #expect(ReviewRiskTermMatcher.range(of: "group chat", in: "Start a group\n  chat today") != nil)
        #expect(ReviewRiskTermMatcher.range(of: "group chat", in: "group chatter") == nil)
    }

    @Test func chineseMatchesInsideText() {
        #expect(ReviewRiskTermMatcher.range(of: "直播", in: "随时开启直播，和朋友互动") != nil)
        #expect(ReviewRiskTermMatcher.range(of: "AI绘画", in: "一键AI绘画") != nil)
    }

    @Test func exclusionsStopAMatch() {
        let exclusions = ReviewRiskSignalTopic.simulatedGambling.exclusions
        #expect(ReviewRiskTermMatcher.range(of: "poker", in: "Planning poker for your team", excluding: exclusions) == nil)
        #expect(ReviewRiskTermMatcher.range(of: "poker", in: "Texas poker nights", excluding: exclusions) != nil)
    }

    @Test func excerptKeepsTheWordsAround() {
        let text = String(repeating: "word ", count: 40) + "group chat " + String(repeating: "more ", count: 40)
        let range = ReviewRiskTermMatcher.range(of: "group chat", in: text)
        let excerpt = range.map { ReviewRiskTermMatcher.excerpt(around: $0, in: text) } ?? ""
        #expect(excerpt.contains("group chat"))
        #expect(excerpt.hasPrefix("…"))
        #expect(excerpt.hasSuffix("…"))
    }
}
