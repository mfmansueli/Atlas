//
//  HowSureWeightingTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The banner's how sure, weighted by the suggested countries' page views.
@Suite("HowSureWeighting")
struct HowSureWeightingTests {
    private func entry(_ level: HowSure, _ pageViews: Int) -> HowSureWeighting.Entry {
        HowSureWeighting.Entry(level: level, pageViews: pageViews)
    }

    @Test func noPageViewsIsNotVerySure() {
        #expect(HowSureWeighting.level([]) == .notVerySure)
        #expect(HowSureWeighting.level([entry(.sure, 0), entry(.sure, 0)]) == .notVerySure)
    }

    @Test func eightyPercentInSureCountriesIsSure() {
        #expect(HowSureWeighting.level([entry(.sure, 800), entry(.notVerySure, 200)]) == .sure)
    }

    @Test func justUnderEightyPercentIsNot() {
        #expect(HowSureWeighting.level([entry(.sure, 799), entry(.notVerySure, 201)]) == .notVerySure)
        #expect(HowSureWeighting.level([entry(.sure, 799), entry(.fairlySure, 1), entry(.notVerySure, 200)]) == .fairlySure)
    }

    @Test func sureCountriesCountTowardFairlySure() {
        #expect(HowSureWeighting.level([entry(.sure, 500), entry(.fairlySure, 400), entry(.notVerySure, 100)]) == .fairlySure)
    }

    @Test func aFewQuietCountriesDontDragTheLevelDown() {
        // The old rule took the weakest country: one Not very sure made it all so.
        let entries = [entry(.fairlySure, 9000)] + (0..<40).map { _ in entry(.notVerySure, 10) }
        #expect(HowSureWeighting.level(entries) == .fairlySure)
    }
}
