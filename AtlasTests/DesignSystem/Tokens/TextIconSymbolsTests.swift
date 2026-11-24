//
//  TextIconSymbolsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// README-DS §13: the models that once wrote "✓", "▲", "▼", "⚠︎" into
/// their text now say which SF Symbol goes before it, and the text is only
/// words.
@MainActor
@Suite("Symbols in place of text icons")
struct TextIconSymbolsTests {
    @Test func theViewerSaysUsedWithACheckmark() {
        let used = StudioViewerAction.useCapture(captureID: "c", screenID: "s", screenName: "Week", isUsed: true)
        #expect(used.title(showsGuide: false) == "Used for Week")
        #expect(used.systemImage == "checkmark")
        let unused = StudioViewerAction.useCapture(captureID: "c", screenID: "s", screenName: "Week", isUsed: false)
        #expect(unused.systemImage == nil)
        #expect(StudioViewerAction.headerGuide.systemImage == nil)
    }

    @Test func aPageAboveOrBelowDefaultHasItsArrow() {
        #expect(ProductPageComparison.above(points: 2.1).text.hasSuffix(" pt above default"))
        #expect(!ProductPageComparison.above(points: 2.1).text.contains("▲"))
        #expect(ProductPageComparison.above(points: 2.1).systemImage == "arrowtriangle.up.fill")
        #expect(ProductPageComparison.below(points: 6.1).text.hasSuffix(" pt below default"))
        #expect(!ProductPageComparison.below(points: 6.1).text.contains("▼"))
        #expect(ProductPageComparison.below(points: 6.1).systemImage == "arrowtriangle.down.fill")
        #expect(ProductPageComparison.aboutTheSame.systemImage == nil)
        #expect(ProductPageComparison.tooFewViews(96).systemImage == nil)
    }

    @Test func theComparisonTableDrawsIncludedAsACheckmark() {
        #expect(ProComparisonRow.isIncluded(ProComparisonRow.yes))
        #expect(!ProComparisonRow.isIncluded(ProComparisonRow.none))
        #expect(ProComparisonRow.all.allSatisfy { !$0.free.contains("✓") && !$0.pro.contains("✓") })
        #expect(ProComparisonRow.all.contains { ProComparisonRow.isIncluded($0.pro) })
    }

    @Test func standingsAreArrowSymbols() {
        #expect(RateStanding.better.systemImage == "arrowtriangle.up.fill")
        #expect(RateStanding.worse.systemImage == "arrowtriangle.down.fill")
        #expect(RateStanding.same.systemImage == "equal")
    }

    @Test func emptyNominationListsAndHelpGroupsHaveTheBoardsSymbols() {
        #expect(NominationState.draft.emptySystemImage == "doc")
        #expect(NominationState.submitted.emptySystemImage == "paperplane")
        #expect(NominationState.archived.emptySystemImage == "archivebox")
        #expect(HelpGroup.start.systemImage == "flag")
        #expect(HelpGroup.listing.systemImage == "doc.text")
        #expect(HelpGroup.after.systemImage == "chart.bar")
        #expect(HelpGroup.atlas.systemImage == "macwindow")
    }
}
