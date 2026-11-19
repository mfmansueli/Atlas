//
//  MenuBarGlyph.swift
//  Atlas
//

import AppKit

/// The menu bar icon from the design's board 46: the globe and its band in
/// one colour, drawn on a 1024-unit square like the app icon and returned
/// as a template image so macOS tints it for light and dark menu bars.
/// Working is eight frames of a bright stretch sweeping round the globe
/// (thinner and dimmer behind it), one lap in 2.6 s.
enum MenuBarGlyph {
    /// The menu bar's size, in points.
    static let size: CGFloat = 18
    static let frameCount = 8
    /// One lap of the working loop.
    static let lap: TimeInterval = 2.6
    static var frameInterval: TimeInterval { lap / Double(frameCount) }

    /// The front stretch's offset when the icon stays still while working
    /// (Reduce Motion, or the setting off): parked at the front.
    static let stillOffset: Double = -16

    /// `frame` picks the working loop's frame (0–7); nil draws the still one.
    static func image(for state: MenuBarIconState, frame: Int? = nil, size: CGFloat = size) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.scaleBy(x: rect.width / 1024, y: rect.height / 1024)
            context.translateBy(x: 512, y: 512)
            draw(state, frame: frame, in: context)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = state.accessibilityLabel
        return image
    }

    /// The front stretch's dash offset for a frame of the loop, as the
    /// design's SVG has it: 18 at the first frame, 12.5 less at each.
    static func frontOffset(frame: Int) -> Double {
        18 - 12.5 * Double(((frame % frameCount) + frameCount) % frameCount)
    }

    // MARK: - Drawing

    private static func draw(_ state: MenuBarIconState, frame: Int?, in context: CGContext) {
        switch state {
        case .idle:
            drawGlobe(in: context)
        case .working:
            drawWorking(frontOffset: frame.map(frontOffset(frame:)) ?? stillOffset, in: context)
        case .needsYou:
            let dot = CGPoint(x: 345, y: -335)
            drawGlobe(in: context) { $0.fillEllipse(in: circle(at: dot, radius: 180)) }
            context.setAlpha(1)
            context.fillEllipse(in: circle(at: dot, radius: 112))
        case .paused:
            context.saveGState()
            context.setAlpha(0.4)
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            drawGlobe(in: context)
            context.endTransparencyLayer()
            context.restoreGState()
            context.setAlpha(1)
            for x in [-112.0, 34] {
                context.addPath(CGPath(roundedRect: CGRect(x: x, y: -125, width: 78, height: 250), cornerWidth: 22, cornerHeight: 22, transform: nil))
            }
            context.fillPath()
        case .cantConnect:
            let slash = { (context: CGContext, width: CGFloat) in
                context.setLineWidth(width)
                context.setLineCap(.round)
                context.move(to: CGPoint(x: -400, y: 400))
                context.addLine(to: CGPoint(x: 400, y: -400))
                context.strokePath()
            }
            drawGlobe(in: context) { slash($0, 190) }
            context.setAlpha(1)
            slash(context, 84)
        }
    }

    /// The still globe: the sphere's rim and the band's back half, cut
    /// where the front half crosses them (and by `cut`), then the front
    /// half over them.
    private static func drawGlobe(in context: CGContext, cut: ((CGContext) -> Void)? = nil) {
        drawSphereAndBack(backAlpha: 0.5, in: context, cut: cut)
        context.setAlpha(1)
        strokeBand(.front, from: 0, to: 1, width: 90, cap: .round, in: context)
    }

    private static func drawWorking(frontOffset: Double, in context: CGContext) {
        drawSphereAndBack(backAlpha: 0.3, in: context, cut: nil)
        context.setAlpha(0.34)
        strokeBand(.front, from: 0, to: 1, width: 90, cap: .round, in: context)
        // The stretch: an 18-unit dash on each 50-unit half, 100 apart, so
        // one is on the front while the other is behind.
        context.setAlpha(0.6)
        strokeDash(.back, offset: frontOffset + 50, width: 70, in: context)
        context.setAlpha(1)
        strokeDash(.front, offset: frontOffset, width: 104, in: context)
    }

    private static func drawSphereAndBack(backAlpha: CGFloat, in context: CGContext, cut: ((CGContext) -> Void)?) {
        context.saveGState()
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.setAlpha(1)
        context.setLineWidth(78)
        context.strokeEllipse(in: circle(at: .zero, radius: 300))
        context.setAlpha(backAlpha)
        strokeBand(.back, from: 0, to: 1, width: 52, cap: .round, in: context)
        // The mask: the front half, wider, and anything else to cut.
        context.setAlpha(1)
        context.setBlendMode(.clear)
        strokeBand(.front, from: 0, to: 1, width: 176, cap: .round, in: context)
        cut?(context)
        context.endTransparencyLayer()
        context.restoreGState()
    }

    /// An SVG dash of 18 with a gap of 82 on a 50-unit half, at `offset`:
    /// what of [-offset, -offset + 18] (mod 100) falls on the half.
    private static func strokeDash(_ half: GlobeBand.Half, offset: Double, width: CGFloat, in context: CGContext) {
        var start = (-offset).truncatingRemainder(dividingBy: 100)
        if start < 0 { start += 100 }
        for dash in [(start, start + 18), (start - 100, start - 82)] {
            let low = max(0, dash.0), high = min(50, dash.1)
            guard high > low else { continue }
            strokeBand(half, from: low / 50, to: high / 50, width: width, cap: .butt, in: context)
        }
    }

    private static func strokeBand(
        _ half: GlobeBand.Half, from start: Double, to end: Double, width: CGFloat, cap: CGLineCap, in context: CGContext
    ) {
        context.addPath(GlobeBand.menuBar.path(half, from: start, to: end))
        context.setLineWidth(width)
        context.setLineCap(cap)
        context.strokePath()
    }

    private static func circle(at center: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}
