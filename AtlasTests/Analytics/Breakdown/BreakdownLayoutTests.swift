//
//  BreakdownLayoutTests.swift
//  AtlasTests
//

import CoreGraphics
import Testing
@testable import Atlas

/// Board 92's Break It Down at each width: under 940 pt the counts hide
/// and the inspector slides over the table; the Proceeds column can be
/// tinted; the five splits in the segmented control.
@Suite("Analytics · Break It Down layout")
struct BreakdownLayoutTests {
    private let counts: Set<BreakdownColumn> = [.impressions, .downloads, .starts]

    @Test func wideTablesShowEveryCountUntilTheInspectorOpens() {
        let wide = BreakdownColumnLayout.make(width: 1000, hasInspector: false, hasSales: true)
        #expect(!wide.isCompact)
        #expect(counts.isSubset(of: Set(wide.columns)))
        #expect(wide.columns == [.impressions, .pageViews, .viewRate, .downloads, .downloadRate, .starts, .startRate, .proceeds])

        // The inspector beside the table: the counts move into it.
        let beside = BreakdownColumnLayout.make(width: 1000, hasInspector: true, hasSales: true)
        #expect(beside.isCompact)
        #expect(Set(beside.columns).isDisjoint(with: counts))
        #expect(!BreakdownColumnLayout.inspectorOverlays(width: 1000))
    }

    @Test func under940TheCountsHideAndTheInspectorSlidesOver() {
        #expect(Metrics.breakdownCompactWidth == 940)
        for width: CGFloat in [860, 939] {
            let layout = BreakdownColumnLayout.make(width: width, hasInspector: false, hasSales: true)
            #expect(layout.isCompact, "\(width)")
            #expect(layout.columns == [.pageViews, .viewRate, .downloadRate, .startRate, .proceeds], "\(width)")
            #expect(BreakdownColumnLayout.inspectorOverlays(width: width), "\(width)")
        }
        #expect(!BreakdownColumnLayout.make(width: 940, hasInspector: false, hasSales: true).isCompact)
        #expect(!BreakdownColumnLayout.inspectorOverlays(width: 940))
    }

    @Test func narrowColumnsAreNarrower() {
        let wide = BreakdownColumnLayout.make(width: 1000, hasInspector: false, hasSales: true)
        let narrow = BreakdownColumnLayout.make(width: 860, hasInspector: false, hasSales: true)
        #expect(narrow.width(of: .viewRate) < wide.width(of: .viewRate))
        #expect(narrow.width(of: .proceeds) == wide.width(of: .proceeds))
    }

    @Test func theAfterDownloadGroupKeepsDownloadsUnlessNarrow() {
        let wide = BreakdownColumnLayout.make(width: 1000, hasInspector: false, hasSales: true, group: .afterDownload)
        #expect(wide.columns.contains(.downloads))
        #expect(!wide.columns.contains(.proceeds))
        let narrow = BreakdownColumnLayout.make(width: 900, hasInspector: false, hasSales: true, group: .afterDownload)
        #expect(!narrow.columns.contains(.downloads))
    }

    @Test func onlyTheHighlightedColumnIsTinted() {
        let layout = BreakdownColumnLayout.make(width: 1000, hasInspector: false, hasSales: true, highlighted: .proceeds)
        #expect(layout.isHighlighted(.proceeds))
        #expect(!layout.isHighlighted(.downloads))
        #expect(!BreakdownColumnLayout.make(width: 1000, hasInspector: false, hasSales: true).isHighlighted(.proceeds))
    }

    @Test func theSegmentedControlShowsFiveSplitsAndMoreHoldsTheRest() {
        #expect(BreakdownDimension.segmented == [.territory, .language, .source, .device, .productPage])
        #expect(BreakdownDimension.more == [.referrer, .campaign])
        #expect(BreakdownDimension.territory.segmentTitle == "Country")
        #expect(BreakdownDimension.territory.totalsTitle == "All territories")
        #expect(BreakdownDimension.language.columnTitle == "Store page language")
        #expect(BreakdownDimension.source.segmentTitle == BreakdownDimension.source.title)
        #expect(!BreakdownDimension.referrer.isSegmented)
    }
}
