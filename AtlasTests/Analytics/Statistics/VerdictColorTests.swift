//
//  VerdictColorTests.swift
//  AtlasTests
//

import SwiftUI
import Testing
@testable import Atlas

/// In the newer tables only "worse" gets a colour (README-An2): Better is
/// drawn like any label, About the same in the secondary label.
@Suite("Analytics · only worse gets a colour")
struct VerdictColorTests {
    @Test func outcomesStandAgainstTheReference() {
        #expect(ComparisonOutcome.higher(.sure).standing == .better)
        #expect(ComparisonOutcome.lower(.fairlySure).standing == .worse)
        #expect(ComparisonOutcome.same.standing == .same)
        #expect(ComparisonOutcome.tooFew.standing == nil)
    }

    @Test func betterIsNotGreen() {
        #expect(RateLabel.verdictColor(for: .better) == Palette.label)
        #expect(RateLabel.verdictColor(for: .better) != Palette.ok)
        #expect(RateLabel.verdictColor(for: .worse) == Palette.warn)
        #expect(RateLabel.verdictColor(for: .same) == Palette.label2)
        #expect(RateLabel.verdictColor(for: nil) == Palette.label2)
    }
}
