//
//  TextWordDiffTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The words a revision changes: whole words with their spaces,
/// punctuation apart, Chinese and Japanese character by character; the
/// same and removed parts give the old text back, the same and added
/// parts the new one.
@Suite("TextWordDiff")
struct TextWordDiffTests {
    private static func joined(_ diff: TextWordDiff, keeping side: (TextWordDiff.Segment) -> String?) -> String {
        diff.segments.compactMap(side).joined()
    }

    private static func old(_ segment: TextWordDiff.Segment) -> String? {
        switch segment {
        case let .same(text), let .removed(text): text
        case .added: nil
        }
    }

    private static func new(_ segment: TextWordDiff.Segment) -> String? {
        switch segment {
        case let .same(text), let .added(text): text
        case .removed: nil
        }
    }

    @Test(arguments: [
        ("…reach the 7-day streak milestone by Sunday.", "…reach the 7-day streak milestone by December 2."),
        ("até domingo.", "até 2 de dezembro."),
        ("bis Sonntag.", "bis 2. Dezember."),
        ("", "New text"),
        ("Old text", ""),
        ("日曜日までに達成", "12月2日までに達成"),
        ("Same words", "Same words"),
    ])
    func bothSidesComeBack(old: String, new: String) {
        let diff = TextWordDiff(from: old, to: new)
        #expect(Self.joined(diff, keeping: Self.old) == old)
        #expect(Self.joined(diff, keeping: Self.new) == new)
    }

    @Test func aChangedDayIsMarkedAsOneChange() {
        let diff = TextWordDiff(from: "Reach the milestone by Sunday.", to: "Reach the milestone by December 2.")
        #expect(diff.marked == "Reach the milestone by [-Sunday-]{+December 2+}.")
        #expect(diff.removedWords == ["Sunday"])
        #expect(diff.addedWords == ["December 2"])
        #expect(diff.hasChanges)
    }

    @Test func wordsAreNotSplitInsideThemselves() {
        // "Sunday" and "Monday" share "day", but change as whole words.
        let diff = TextWordDiff(from: "by Sunday", to: "by Monday")
        #expect(diff.segments == [.same("by "), .removed("Sunday"), .added("Monday")])
    }

    @Test func anApostropheStaysInItsWord() {
        #expect(TextWordDiff.tokens("Don’t stop, it's fine") == ["Don’t ", "stop", ", ", "it's ", "fine"])
    }

    @Test func japaneseChangesCharacterByCharacter() {
        let diff = TextWordDiff(from: "日曜日まで", to: "12月2日まで")
        #expect(diff.addedWords.joined().contains("12月2"))
        #expect(diff.segments.last == .same("日まで"))
    }

    @Test func theSameTextHasNoChanges() {
        let diff = TextWordDiff(from: "Same words.", to: "Same words.")
        #expect(!diff.hasChanges)
        #expect(diff.segments == [.same("Same words.")])
        #expect(diff.marked == "Same words.")
    }
}
