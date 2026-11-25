//
//  InAppEventMediaMemoryTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A language whose media read fails keeps what the last read that worked
/// found, so its card doesn't fall back to the gradient.
@Suite("InAppEventMediaMemory")
@MainActor
struct InAppEventMediaMemoryTests {
    private let card = InAppEventMedia(kind: .card, isVideo: true, fileName: "gratitude-card.mov", fileSize: 8_652_567)
    private let details = InAppEventMedia(kind: .details, isVideo: true, fileName: "gratitude-details.mov", fileSize: 9_473_285)

    @Test func whatWorkedIsKeptAndReturned() {
        let memory = InAppEventMediaMemory()
        let settled = memory.settle(["en": [card, details], "de": []])
        #expect(settled["en"] == [card, details])
        #expect(settled["de"] == [])
    }

    @Test func aFailedLanguageKeepsWhatItHad() {
        let memory = InAppEventMediaMemory()
        _ = memory.settle(["en": [card, details], "de": [card]])
        let settled = memory.settle(["en": nil, "de": [details]])
        #expect(settled["en"] == [card, details])
        #expect(settled["de"] == [details])
    }

    @Test func aFailedLanguageNeverReadIsLeftOut() {
        let memory = InAppEventMediaMemory()
        let settled = memory.settle(["ja": nil])
        #expect(settled["ja"] == nil)
    }

    /// Art taken off in App Store Connect goes: an empty read that worked
    /// isn't a failure.
    @Test func anEmptyReadThatWorkedReplacesTheArt() {
        let memory = InAppEventMediaMemory()
        _ = memory.settle(["en": [card]])
        #expect(memory.settle(["en": []])["en"] == [])
        #expect(memory.settle(["en": nil])["en"] == [])
    }
}
