//
//  SidebarFooterFitTests.swift
//  AtlasTests
//

import CoreGraphics
import Testing
@testable import Atlas

/// The sidebar's footer keeps Settings, Show the Tour and Atlas Help as
/// rows while they fit under the sections, folds them into a row of icons
/// when they don't, and lets the sections scroll under it only when even
/// that doesn't fit.
@Suite("SidebarFooterFit")
struct SidebarFooterFitTests {
    /// Alba's sidebar as measured at 1100 × 612: a 140 pt header, 348 pt
    /// of sections and a 143 pt footer.
    private func fit(_ height: CGFloat, span: CGFloat? = 348) -> SidebarFooterFit {
        var fit = SidebarFooterFit(sidebarHeight: height, headerHeight: 140, fullFooterHeight: 143)
        guard let first = AppWorkspaceSection.sidebarFirst, let last = AppWorkspaceSection.sidebarLast else { return fit }
        _ = fit.report(section: first, top: 300, bottom: 332)
        if let span { _ = fit.report(section: last, top: 300 + span - 32, bottom: 300 + span) }
        return fit
    }

    @Test func aTallWindowKeepsTheRows() {
        // 140 + 24 + 348 + 143 = 655.
        #expect(!fit(655).isCompact)
        #expect(!fit(900).sectionsScrollUnder)
    }

    @Test func aShortWindowFoldsThemIntoIcons() {
        let fit = fit(612)
        #expect(fit.isCompact)
        // Folded, the footer takes 75 pt: 587 fits in 612.
        #expect(!fit.sectionsScrollUnder)
    }

    @Test func onlyAVeryShortWindowScrollsTheSectionsUnder() {
        #expect(fit(587).isCompact)
        #expect(!fit(587).sectionsScrollUnder)
        #expect(fit(586).sectionsScrollUnder)
    }

    @Test func aLastSectionOutOfSightMeansNoRoom() {
        let fit = fit(500, span: nil)
        #expect(fit.isCompact)
        #expect(fit.sectionsScrollUnder)
    }

    @Test func nothingFoldsBeforeItsMeasuredOrWithoutSections() {
        #expect(!SidebarFooterFit().isCompact)
        // No app chosen: no section reported.
        let empty = SidebarFooterFit(sidebarHeight: 300, headerHeight: 140, fullFooterHeight: 143)
        #expect(!empty.isCompact)
    }

    @Test func theSpanDoesntChangeAsTheListScrolls() {
        var scrolled = fit(612)
        guard let first = AppWorkspaceSection.sidebarFirst, let last = AppWorkspaceSection.sidebarLast else { return }
        _ = scrolled.report(section: first, top: 250, bottom: 282)
        _ = scrolled.report(section: last, top: 250 + 316, bottom: 250 + 348)
        #expect(scrolled.sectionsSpan == 348)
        #expect(scrolled.isCompact && !scrolled.sectionsScrollUnder)
    }

    @Test func foldedItKeepsTheRowsHeightItLastSaw() {
        var fit = fit(612)
        fit.footerMeasured(80)
        // The larger of the 143 seen and 80 + 68.
        #expect(fit.fullFooterHeight == 148)
        // The version's status went: the rows would be 30 pt shorter too.
        fit.footerMeasured(50)
        #expect(fit.fullFooterHeight == 118)
        #expect(fit.compactFooterHeight == 50)
    }

    @Test func foldingDoesntFlipBackAndForth() {
        // Just too short for the rows: folds, and measuring the folded
        // footer doesn't make the rows look as if they fit again.
        var fit = fit(654)
        #expect(fit.isCompact)
        fit.footerMeasured(75)
        #expect(fit.isCompact)
        fit.sidebarHeight = 700
        #expect(!fit.isCompact)
        fit.footerMeasured(143)
        #expect(!fit.isCompact)
        #expect(fit.compactFooterHeight == nil)
    }
}
