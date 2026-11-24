//
//  ToolbarItemFitView.swift
//  Atlas
//

import AppKit

/// Sits behind a SwiftUI toolbar item's content and keeps the item as wide
/// as its content wants. AppKit's toolbar gives each item a fixed width
/// when it lays the toolbar out; once the window was too narrow for an
/// item (at launch, or resized to the 860 pt minimum), that width stays
/// after the window widens or the item's text grows. The content then
/// truncates (“Suggest Ever…”) or spills out of its place, centred, under
/// the sidebar button (the section's title). Each time the window resizes
/// or the content changes, this asks the item for its width again.
final class ToolbarItemFitView: NSView {
    /// The window's resize notifications, while in a window; a view taken
    /// out of its window (always before it goes) drops them.
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        guard let window else { return }
        for name in [NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refit() }
            })
        }
        // The sidebar dragged wider or narrower, shown or hidden: the
        // toolbar's room changes with the window's size unchanged. Any split
        // view's: a check that finds the item fitting does nothing.
        observers.append(NotificationCenter.default.addObserver(
            forName: NSSplitView.didResizeSubviewsNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refit() }
        })
        refit()
    }

    /// After SwiftUI updates the content: the item's width is checked on the
    /// next turn of the run loop, once the content has its new size.
    func refit() {
        DispatchQueue.main.async { [weak self] in
            self?.refitIfNeeded()
        }
    }

    /// Asks the item's viewer for its width again when the content wants
    /// another one; true when it asked.
    @discardableResult
    func refitIfNeeded() -> Bool {
        guard let host = itemHostingView, let viewer = host.superview else { return false }
        let wanted = host.intrinsicContentSize.width
        guard Self.needsRefit(width: host.frame.width, wanted: wanted) else { return false }
        host.invalidateIntrinsicContentSize()
        viewer.invalidateIntrinsicContentSize()
        viewer.needsUpdateConstraints = true
        viewer.needsLayout = true
        viewer.superview?.needsLayout = true
        return true
    }

    /// The SwiftUI view that holds the item's content: the ancestor whose
    /// superview is the toolbar's viewer for that item.
    private var itemHostingView: NSView? {
        var view: NSView? = superview
        while let current = view {
            if let parent = current.superview, Self.isItemViewer(parent) { return current }
            view = current.superview
        }
        return nil
    }

    static func isItemViewer(_ view: NSView) -> Bool {
        String(describing: type(of: view)).contains("ToolbarItemViewer")
    }

    /// Off by more than half a point, and the content wants a real width.
    static func needsRefit(width: CGFloat, wanted: CGFloat) -> Bool {
        wanted > 0 && abs(width - wanted) > 0.5
    }
}
