//
//  AnalyticsSectionBadgeTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Workspace · Analytics in the sidebar")
struct AnalyticsSectionBadgeTests {
    @Test func analyticsIsTheLastSectionAfterRelease() {
        #expect(AppWorkspaceSection.allCases.last == .analytics)
        #expect(AppWorkspaceSection.analytics.shortcutDigit == "9")
        #expect(AppWorkspaceSection.analytics.title == "Analytics")
        #expect(AppWorkspaceSection.analytics.group == .afterRelease)
    }

    @Test func newFindingsAreAGrayCountOfTheirOwn() {
        let counts = SectionBadgeCounts([.storePage: 3], newFindings: 2)
        #expect(counts.text(for: .analytics) == "2")
        #expect(counts.isNeutral(.analytics))
        #expect(!counts.isNeutral(.storePage))
        // The sidebar's purple total is suggestions only.
        #expect(counts.total == 3)
        #expect(counts.accessibilitySummary == "Store Page, 3 suggestions to review. Analytics, 2 new findings")
        #expect(SectionBadgeCounts([:], newFindings: 0).text(for: .analytics) == nil)
        #expect(SectionBadgeCounts([:], newFindings: 1).accessibilitySummary == "Analytics, 1 new finding")
    }

    @Test func aFindingOpensItsSection() {
        #expect(FindingAction.storePage(locale: "de-DE").area.section == .storePage)
        #expect(FindingAction.inAppTexts.area.section == .storePage)
        #expect(FindingAction.retention.area.section == .subscriptionPricing)
        #expect(FindingAction.pricing(territory: "BR").title == "Open Pricing for Brazil")
        #expect(FindingAction.screenshots(locale: nil).title == "Open Screenshots")
    }
}
