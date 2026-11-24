//
//  SidebarFitTests.swift
//  AtlasTests
//

import CoreGraphics
import Testing
@testable import Atlas

/// Board 71: the footer is the same at every height; a sidebar under
/// 600 pt tightens its rows and drops the "other apps" line; the sections
/// scroll under the footer only when they still don't fit.
@Suite("SidebarFit")
struct SidebarFitTests {
    /// A 140 pt header, 348 pt of sections and an 84 pt footer.
    private func fit(_ height: CGFloat, span: CGFloat? = 348) -> SidebarFit {
        var fit = SidebarFit(sidebarHeight: height, headerHeight: 140, footerHeight: 84)
        guard let first = AppWorkspaceSection.sidebarFirst, let last = AppWorkspaceSection.sidebarLast else { return fit }
        _ = fit.report(section: first, top: 300, bottom: 332)
        if let span { _ = fit.report(section: last, top: 300 + span - 32, bottom: 300 + span) }
        return fit
    }

    @Test func compactRulesStartUnder600() {
        #expect(!fit(780).isCompact)
        #expect(!fit(600).isCompact)
        #expect(fit(599).isCompact)
        #expect(fit(560).isCompact)
    }

    @Test func compactRowsAre27Points() {
        #expect(fit(780).rowHeight == 32)
        #expect(fit(560).rowHeight == 27)
    }

    @Test func nothingIsCompactBeforeItsMeasured() {
        #expect(!SidebarFit().isCompact)
        #expect(SidebarFit().rowHeight == 32)
    }

    @Test func sectionsThatFitDontScrollUnder() {
        // 140 + 24 + 348 + 84 = 596.
        #expect(!fit(596).sectionsScrollUnder)
        #expect(!fit(780).sectionsScrollUnder)
    }

    @Test func sectionsThatDontFitScrollUnder() {
        #expect(fit(595).sectionsScrollUnder)
    }

    @Test func aLastSectionOutOfSightMeansNoRoom() {
        #expect(fit(500, span: nil).sectionsScrollUnder)
    }

    @Test func nothingScrollsUnderBeforeItsMeasuredOrWithoutSections() {
        #expect(!SidebarFit().sectionsScrollUnder)
        // No app chosen: no section reported.
        let empty = SidebarFit(sidebarHeight: 300, headerHeight: 140, footerHeight: 84)
        #expect(!empty.sectionsScrollUnder)
    }

    @Test func theSpanDoesntChangeAsTheListScrolls() {
        var scrolled = fit(560)
        guard let first = AppWorkspaceSection.sidebarFirst, let last = AppWorkspaceSection.sidebarLast else { return }
        _ = scrolled.report(section: first, top: 250, bottom: 282)
        _ = scrolled.report(section: last, top: 250 + 316, bottom: 250 + 348)
        #expect(scrolled.sectionsSpan == 348)
    }

    @Test func onlyTheEndsAreKept() {
        var fit = fit(780)
        let middle = AppWorkspaceSection.allCases.first { $0 != AppWorkspaceSection.sidebarFirst && $0 != AppWorkspaceSection.sidebarLast }
        guard let middle else { return }
        let changed = fit.report(section: middle, top: 10, bottom: 40)
        #expect(!changed)
    }
}
