//
//  DebugSnapshot.swift
//  Atlas
//

#if DEBUG
import AppKit

/// DEBUG-only: a picture of the window without WindowServer, for comparing
/// scenes with the design's PNGs while the screen is locked (when
/// `screencapture` can't read windows).
///
/// `-AtlasDebugSnapshot <seconds>` waits, renders the largest window (and a
/// sheet on it, placed where macOS puts sheets) through `cacheDisplay`, and
/// writes the PNG to file descriptor 3, which the launching shell opened
/// (`3> out.png`): inherited descriptors work inside the App Sandbox.
/// `-AtlasDebugWindowSize 1200x780` sizes the window first. Atlas quits
/// once the picture is written.
@MainActor
enum DebugSnapshot {
    static func startIfRequested(arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard let delay = value(after: "-AtlasDebugSnapshot", in: arguments).flatMap(Double.init) else { return }
        let size = value(after: "-AtlasDebugWindowSize", in: arguments).flatMap(parseSize)
        let appearance = appearance(named: value(after: "-AtlasDebugAppearance", in: arguments))
        Task { @MainActor in
            if let appearance { NSApplication.shared.appearance = appearance }
            // Sized as soon as the window exists, so the scene lays out once at that size.
            for _ in 0..<40 {
                if let window = mainWindow() {
                    if let size { resize(window, to: size) }
                    if let appearance { window.appearance = appearance }
                    break
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
            try? await Task.sleep(for: .seconds(delay))
            await prepareForPicture(appearance: appearance)
            if let window = mainWindow(), let data = picture(of: window) {
                FileHandle(fileDescriptor: 3, closeOnDealloc: false).write(data)
            } else {
                NSLog("DebugSnapshot: no window to render")
            }
            exit(0)
        }
    }

    /// Makes the window key, so filled buttons draw in the accent colour,
    /// not the grey of an inactive window (still grey while the screen is
    /// locked), and applies the appearance again to it and its sheet.
    private static func prepareForPicture(appearance: NSAppearance?) async {
        guard let window = mainWindow() else { return }
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
        guard let appearance else { return }
        window.appearance = appearance
        window.attachedSheet?.appearance = appearance
        try? await Task.sleep(for: .seconds(1))
    }

    /// "dark" or "light"; nil keeps the system's.
    private static func appearance(named name: String?) -> NSAppearance? {
        switch name {
        case "dark": NSAppearance(named: .darkAqua)
        case "light": NSAppearance(named: .aqua)
        default: nil
        }
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func parseSize(_ text: String) -> CGSize? {
        let parts = text.split(separator: "x").compactMap { Double($0) }
        return parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : nil
    }

    private static func mainWindow() -> NSWindow? {
        NSApp.windows
            .filter { $0.isVisible && $0.sheetParent == nil && $0.styleMask.contains(.titled) }
            .max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
    }

    private static func resize(_ window: NSWindow, to size: CGSize) {
        var frame = window.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        window.setFrame(frame, display: true)
    }

    /// The window's whole frame (title bar and toolbar included), with its
    /// sheet drawn over it under the toolbar, centred.
    private static func picture(of window: NSWindow) -> Data? {
        guard let frameView = window.contentView?.superview, let base = render(frameView) else { return nil }
        let scale = window.backingScaleFactor
        let image = NSImage(size: frameView.bounds.size)
        image.addRepresentation(base)
        if let sheet = window.attachedSheet, let sheetView = sheet.contentView?.superview, let rendered = render(sheetView) {
            let composed = NSImage(size: frameView.bounds.size)
            composed.lockFocus()
            image.draw(in: frameView.bounds)
            NSColor.black.withAlphaComponent(0.12).setFill()
            frameView.bounds.fill(using: .sourceAtop)
            let toolbarBottom = window.contentLayoutRect.maxY
            let origin = CGPoint(x: (frameView.bounds.width - sheet.frame.width) / 2, y: toolbarBottom - sheet.frame.height)
            let sheetImage = NSImage(size: sheetView.bounds.size)
            sheetImage.addRepresentation(rendered)
            sheetImage.draw(in: CGRect(origin: origin, size: sheet.frame.size))
            composed.unlockFocus()
            return png(composed, scale: scale)
        }
        return base.representation(using: .png, properties: [:])
    }

    /// Draws the view's layer tree: tables and lists draw only through
    /// their layers, and `cacheDisplay` misses them. Materials (sidebar,
    /// toolbar glass) can't be drawn offscreen, so the window's background
    /// goes underneath.
    private static func render(_ view: NSView) -> NSBitmapImageRep? {
        view.layoutSubtreeIfNeeded()
        // Tables make their rows only when they draw: draw once.
        view.window?.display()
        view.layoutSubtreeIfNeeded()
        guard let layer = view.layer, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        let cgContext = context.cgContext
        // The window's background is a material, drawn by WindowServer:
        // macOS 26's window grey instead.
        let isDark = (view.window?.appearance ?? view.effectiveAppearance).bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let dark = CGColor(srgbRed: 0.118, green: 0.118, blue: 0.129, alpha: 1)
        let light = CGColor(srgbRed: 0.937, green: 0.937, blue: 0.949, alpha: 1)
        cgContext.setFillColor(isDark ? dark : light)
        cgContext.fill(view.bounds)
        layer.render(in: cgContext)
        return rep
    }

    private static func png(_ image: NSImage, scale _: CGFloat) -> Data? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
#endif
