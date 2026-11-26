//
//  RefreshSectionProgressTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Refresh waits for the open section's read: done once the section
/// stamped its model for this Refresh; Nominations never holds it up.
@MainActor
@Suite("Refresh · the open section")
struct RefreshSectionProgressTests {
    private let date = Date(timeIntervalSince1970: 1_793_000_000)

    private func models() -> AppSectionModels {
        AppSectionModels(maximumAge: 15 * 60, now: { [date] in date })
    }

    @Test func aSectionIsReadingUntilItStampsThisRefresh() {
        let models = models()
        #expect(models.refreshProgress(of: .overview, refreshCount: 1) == .reading)
        models.didLoad(.overview, refreshCount: 0)
        #expect(models.refreshProgress(of: .overview, refreshCount: 1) == .reading, "a read from before the Refresh")
        models.didLoad(.overview, refreshCount: 1)
        #expect(models.refreshProgress(of: .overview, refreshCount: 1) == .done)
    }

    @Test func sectionsWithoutAKeptModelDontHoldItUp() {
        let models = models()
        #expect(models.refreshProgress(of: .nominations, refreshCount: 1) == .done)
        #expect(models.refreshProgress(of: .reviews, refreshCount: 1) == .done)
        #expect(models.refreshProgress(of: .storePage, refreshCount: 1) == .reading)
    }
}
