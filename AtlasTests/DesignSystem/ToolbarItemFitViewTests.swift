//
//  ToolbarItemFitViewTests.swift
//  AtlasTests
//

import AppKit
import Testing
@testable import Atlas

/// A toolbar item keeps its content's width: AppKit's viewer is asked for
/// it again when the content wants another width than it has (the title's
/// status read late, Review & Push unfolding after the minimum window), and
/// left alone when it fits.
@Suite("Toolbar item fit")
@MainActor
struct ToolbarItemFitViewTests {
    @Test func refitsOnlyWhenTheWidthIsOffByMoreThanHalfAPoint() {
        #expect(ToolbarItemFitView.needsRefit(width: 76.5, wanted: 174))
        #expect(ToolbarItemFitView.needsRefit(width: 320, wanted: 294))
        #expect(!ToolbarItemFitView.needsRefit(width: 174, wanted: 174))
        #expect(!ToolbarItemFitView.needsRefit(width: 174.4, wanted: 174))
        // No intrinsic width (-1) or none yet: nothing to ask for.
        #expect(!ToolbarItemFitView.needsRefit(width: 80, wanted: -1))
        #expect(!ToolbarItemFitView.needsRefit(width: 80, wanted: 0))
    }

    @Test func knowsTheToolbarsItemViewerByItsClass() {
        #expect(ToolbarItemFitView.isItemViewer(NSToolbarItemViewer()))
        #expect(!ToolbarItemFitView.isItemViewer(NSView()))
    }

    @Test func asksTheViewerAgainWhenTheContentWantsMoreRoom() {
        let (viewer, fit) = item(width: 76.5, wanted: 174)
        viewer.needsUpdateConstraints = false

        #expect(fit.refitIfNeeded())
        #expect(viewer.needsUpdateConstraints)
    }

    @Test func leavesAFittingItemAlone() {
        let (_, fit) = item(width: 174, wanted: 174)

        #expect(!fit.refitIfNeeded())
    }

    @Test func doesNothingOutsideAToolbar() {
        let host = Host(wanted: 174)
        host.frame.size.width = 50
        let fit = ToolbarItemFitView()
        host.addSubview(fit)

        #expect(!fit.refitIfNeeded())
    }

    // MARK: - Helpers

    /// viewer > content host (`width` wide, wanting `wanted`) > background > fit view.
    private func item(width: CGFloat, wanted: CGFloat) -> (NSView, ToolbarItemFitView) {
        let viewer = NSToolbarItemViewer()
        let host = Host(wanted: wanted)
        host.frame = CGRect(x: 0, y: 0, width: width, height: 36)
        viewer.addSubview(host)
        let background = NSView(frame: host.bounds)
        host.addSubview(background)
        let fit = ToolbarItemFitView()
        background.addSubview(fit)
        return (viewer, fit)
    }

    /// Named like AppKit's own viewer, which isn't public.
    private final class NSToolbarItemViewer: NSView {}

    /// A SwiftUI host stand-in that wants `wanted` points.
    private final class Host: NSView {
        let wanted: CGFloat

        init(wanted: CGFloat) {
            self.wanted = wanted
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var intrinsicContentSize: NSSize {
            NSSize(width: wanted, height: 36)
        }
    }
}
