//
//  SkeletonPatternTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The skeletons' line widths: static and the same on every draw (Motion
/// v2: a skeleton never animates), within the row, and wrapping around.
@Suite("Skeleton pattern")
struct SkeletonPatternTests {
    @Test func everyWidthIsAShareOfTheRow() {
        for width in SkeletonPattern.primary + SkeletonPattern.secondary + SkeletonPattern.card + [SkeletonPattern.cardTitle] {
            #expect(width > 0.2 && width < 1, "\(width)")
        }
    }

    @Test func theSecondLineIsShorterThanTheFirst() {
        for row in 0..<SkeletonPattern.primary.count {
            #expect(SkeletonPattern.fraction(row: row, line: 1) < SkeletonPattern.fraction(row: row, line: 0), "row \(row)")
        }
    }

    @Test func rowsWrapAroundThePattern() {
        let count = SkeletonPattern.primary.count
        #expect(SkeletonPattern.fraction(row: count, line: 0) == SkeletonPattern.fraction(row: 0, line: 0))
        #expect(SkeletonPattern.fraction(row: count + 2, line: 1) == SkeletonPattern.fraction(row: 2, line: 1))
        #expect(SkeletonPattern.fraction(row: -1, line: 0) == SkeletonPattern.primary[count - 1])
        #expect(SkeletonPattern.cardFraction(line: SkeletonPattern.card.count) == SkeletonPattern.card[0])
    }

    @Test func neighbouringRowsDiffer() {
        for row in 0..<12 {
            #expect(SkeletonPattern.fraction(row: row, line: 0) != SkeletonPattern.fraction(row: row + 1, line: 0), "row \(row)")
        }
    }

    @Test func sharesStayWithinTheRow() {
        #expect(SkeletonPattern.clamped(1.4) == 1)
        #expect(SkeletonPattern.clamped(-0.2) == 0)
        #expect(SkeletonPattern.clamped(.nan) == 0)
        #expect(SkeletonPattern.clamped(.infinity) == 0)
        #expect(SkeletonPattern.clamped(0.55) == 0.55)
    }
}
