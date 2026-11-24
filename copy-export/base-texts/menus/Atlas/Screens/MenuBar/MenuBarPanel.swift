//
//  MenuBarPanel.swift
//  Atlas
//

import AppKit
import SwiftUI

/// The rounded panel under the menu bar icon that holds the menu or the
/// "still running" note: menu material, no title bar, above other windows,
/// and it never activates Atlas just by opening. The menu closes on Esc
/// and when the person clicks anywhere else; the note stays until its
/// buttons close it.
final class MenuBarPanel: NSPanel {
    /// Whether clicking elsewhere (the panel losing key) closes it.
    var closesWhenInactive = true
    /// When it last closed, so the click on the icon that closed it doesn't
    /// open it again straight away.
    private(set) var closedAt: Date?

    init(content: some View, cornerRadius: CGFloat) {
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .popUpMenu
        hasShadow = true
        isOpaque = false
        backgroundColor = .clear
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        animationBehavior = .utilityWindow

        let background = NSVisualEffectView()
        background.material = .menu
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = cornerRadius
        background.layer?.cornerCurve = .continuous
        background.layer?.masksToBounds = true

        let host = FittingHostingView(rootView: AnyView(content))
        host.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            host.topAnchor.constraint(equalTo: background.topAnchor),
            host.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        contentView = background
        setContentSize(host.fittingSize)
        host.onResize = { [weak self] in self?.fitContent() }
    }

    override var canBecomeKey: Bool { true }

    override var canBecomeMain: Bool { false }

    /// Under the icon at `anchor` (its frame on screen), kept on the screen.
    func show(below anchor: NSRect) {
        if let host = contentView?.subviews.first { setContentSize(host.fittingSize) }
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? anchor
        var origin = NSPoint(x: anchor.minX - 8, y: anchor.minY - frame.height - 4)
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - frame.width - 8)
        origin.y = max(origin.y, visible.minY + 8)
        setFrameOrigin(origin)
        makeKeyAndOrderFront(nil)
    }

    /// As tall as the content, its top edge where it was: a job starting
    /// or finishing grows or shrinks the menu downwards.
    private func fitContent() {
        guard let host = contentView?.subviews.first else { return }
        let size = host.fittingSize
        guard size != frame.size else { return }
        let top = frame.maxY
        setFrame(NSRect(x: frame.minX, y: top - size.height, width: size.width, height: size.height), display: true)
    }

    override func cancelOperation(_: Any?) {
        close()
    }

    override func resignKey() {
        super.resignKey()
        if closesWhenInactive { close() }
    }

    override func close() {
        closedAt = .now
        super.close()
    }

    /// Says when SwiftUI's content changed its size.
    private final class FittingHostingView: NSHostingView<AnyView> {
        var onResize: (() -> Void)?

        override func invalidateIntrinsicContentSize() {
            super.invalidateIntrinsicContentSize()
            DispatchQueue.main.async { [weak self] in self?.onResize?() }
        }
    }
}
