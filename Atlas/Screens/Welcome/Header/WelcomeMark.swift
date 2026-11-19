//
//  WelcomeMark.swift
//  Atlas
//

import SwiftUI

/// The app icon's mark, alive: drawn from the same seven layers as
/// `Atlas.icon` (back orbits, glass sphere, meridian, rim, thin orbit,
/// band, star) on the icon's 1024-unit square, with the tiles riding the
/// band and everything else moving as `WelcomeMotion` says. `isStill`
/// (Reduce Motion) draws the icon as it is: the band's three marks
/// instead of the tiles, nothing turning or glinting.
struct WelcomeMark: View {
    let motion: WelcomeMotion
    var isStill = false

    private static let tileColor = Color(red: 0x2F / 255, green: 0x97 / 255, blue: 0xFA / 255)
    private static let markColor = Color(red: 0x14 / 255, green: 0x83 / 255, blue: 0xF7 / 255)
    private static let band = GlobeBand.icon
    private static let thinOrbit = GlobeBand(rx: 380, ry: 82, rotation: 0)
    private static let starCenter = CGPoint(x: 322, y: -214)

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 1024
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: scale, y: scale)
            draw(in: context)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Atlas: a globe with a band orbiting it"))
        .accessibilityAddTraits(.isImage)
    }

    private func draw(in context: GraphicsContext) {
        let orbit = isStill ? WelcomeMotion.Orbit(lean: 0, openness: 1) : motion.orbit
        let orbitTransform = CGAffineTransform(scaleX: 1, y: orbit.openness)
            .concatenating(CGAffineTransform(rotationAngle: 38 * .pi / 180))
            .concatenating(CGAffineTransform(rotationAngle: orbit.lean * .pi / 180))
        let orbitBack = Path(Self.thinOrbit.path(.back)).applying(orbitTransform)
        let orbitFront = Path(Self.thinOrbit.path(.front)).applying(orbitTransform)
        let bandBack = Path(Self.band.path(.back))
        let bandFront = Path(Self.band.path(.front))
        let globe = Self.circle(radius: 312)
        let tiles = isStill ? [] : motion.tiles

        // Behind the globe: the orbits' back halves, hidden where the
        // sphere is.
        layer(context, opacity: 0.45) { layer in
            layer.stroke(orbitBack, with: .color(.white), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            layer.stroke(bandBack, with: .color(.white), style: StrokeStyle(lineWidth: 64, lineCap: .round))
            layer.blendMode = .destinationOut
            layer.fill(globe, with: .color(.black))
        }
        // Tiles on the back half: dimmed, and only past the globe's edge.
        layer(context, opacity: 0.6) { layer in
            for tile in tiles where !tile.isFront {
                layer.fill(tilePath(tile), with: .color(Self.tileColor))
            }
            layer.blendMode = .destinationOut
            layer.fill(globe, with: .color(.black))
        }
        // The glass sphere, its turning meridian and its rim, cut where
        // the band and the thin orbit pass in front.
        layer(context, opacity: 1) { layer in
            layer.fill(Self.circle(radius: 300), with: .color(.white.opacity(0.35)))
            drawMeridian(in: layer)
            layer.stroke(Self.circle(radius: 300), with: .color(.white), lineWidth: 16)
            layer.blendMode = .destinationOut
            layer.stroke(bandFront, with: .color(.black), style: StrokeStyle(lineWidth: 96, lineCap: .round))
            layer.stroke(orbitFront, with: .color(.black), style: StrokeStyle(lineWidth: 34, lineCap: .round))
        }
        // The thin orbit's front half, cut where the band crosses it.
        layer(context, opacity: 1) { layer in
            layer.stroke(orbitFront, with: .color(.white), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            layer.blendMode = .destinationOut
            layer.stroke(bandFront, with: .color(.black), style: StrokeStyle(lineWidth: 96, lineCap: .round))
        }
        context.stroke(bandFront, with: .color(.white), style: StrokeStyle(lineWidth: 64, lineCap: .round))
        if isStill {
            drawStillMarks(in: context)
        }
        for tile in tiles where tile.isFront {
            context.fill(tilePath(tile), with: .color(Self.tileColor))
        }
        drawStar(in: context)
    }

    private func layer(_ context: GraphicsContext, opacity: Double, _ draw: (inout GraphicsContext) -> Void) {
        var context = context
        context.opacity = opacity
        context.drawLayer { layer in draw(&layer) }
    }

    /// Two ellipses that narrow, flip and widen, so the globe reads as
    /// turning; clipped just inside the rim.
    private func drawMeridian(in context: GraphicsContext) {
        let scales = isStill ? (1.0, 1.0) : motion.meridianScales
        var clipped = context
        clipped.clip(to: Self.circle(radius: 293))
        clipped.rotate(by: .degrees(-14))
        for (scale, opacity) in [(scales.0, 0.5), (scales.1, 0.3)] {
            var meridian = clipped
            meridian.scaleBy(x: scale, y: 1)
            let ellipse = Path(ellipseIn: CGRect(x: -128, y: -300, width: 256, height: 600))
            meridian.stroke(ellipse, with: .color(.white.opacity(opacity)), lineWidth: 12)
        }
    }

    /// A tile at its place on the band, as wide as the band's curve lets
    /// it face you.
    private func tilePath(_ tile: WelcomeMotion.Tile) -> Path {
        let shape = Path(roundedRect: CGRect(x: -23, y: -20, width: 46, height: 40), cornerRadius: 13, style: .continuous)
        let transform = CGAffineTransform(scaleX: tile.widthScale, y: 1)
            .concatenating(CGAffineTransform(translationX: tile.x, y: tile.y))
            .concatenating(CGAffineTransform(rotationAngle: Self.band.rotation * .pi / 180))
        return shape.applying(transform)
    }

    /// The icon's own three marks on the band, for the still header.
    private func drawStillMarks(in context: GraphicsContext) {
        let marks: [(CGFloat, CGFloat, Double)] = [(-192.9, 116.8, -171.8), (-270.9, 102.4, -167.0), (-337.1, 83.6, -160.6)]
        for (x, y, angle) in marks {
            let shape = Path(roundedRect: CGRect(x: -8, y: -21, width: 16, height: 42), cornerRadius: 4)
            let transform = CGAffineTransform(rotationAngle: angle * .pi / 180)
                .concatenating(CGAffineTransform(translationX: x, y: y))
                .concatenating(CGAffineTransform(rotationAngle: Self.band.rotation * .pi / 180))
            context.fill(shape.applying(transform), with: .color(Self.markColor))
        }
    }

    /// The star beside the band's end, and the glow that opens behind it
    /// when it glints.
    private func drawStar(in context: GraphicsContext) {
        let star = isStill ? WelcomeMotion.Star(scale: 1, rotation: 0, opacity: 1, haloScale: 1, haloOpacity: 0) : motion.star
        var context = context
        context.translateBy(x: Self.starCenter.x, y: Self.starCenter.y)
        if star.haloOpacity > 0 {
            var halo = context
            halo.opacity = star.haloOpacity
            halo.scaleBy(x: star.haloScale, y: star.haloScale)
            let gradient = Gradient(stops: [
                .init(color: .white.opacity(0.95), location: 0),
                .init(color: .white.opacity(0.4), location: 0.3),
                .init(color: .white.opacity(0), location: 1),
            ])
            halo.fill(Self.circle(radius: 170), with: .radialGradient(gradient, center: .zero, startRadius: 0, endRadius: 170))
        }
        context.opacity = star.opacity
        context.rotate(by: .degrees(star.rotation))
        context.scaleBy(x: star.scale, y: star.scale)
        context.fill(Self.starPath, with: .color(.white))
    }

    /// The icon's four-pointed star, 96 units across.
    private static let starPath = Path { path in
        path.move(to: CGPoint(x: 0, y: -48))
        path.addCurve(to: CGPoint(x: 48, y: 0), control1: CGPoint(x: 7, y: -11), control2: CGPoint(x: 11, y: -7))
        path.addCurve(to: CGPoint(x: 0, y: 48), control1: CGPoint(x: 11, y: 7), control2: CGPoint(x: 7, y: 11))
        path.addCurve(to: CGPoint(x: -48, y: 0), control1: CGPoint(x: -7, y: 11), control2: CGPoint(x: -11, y: 7))
        path.addCurve(to: CGPoint(x: 0, y: -48), control1: CGPoint(x: -11, y: -7), control2: CGPoint(x: -7, y: -11))
        path.closeSubpath()
    }

    private static func circle(radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
    }
}

#Preview {
    TimelineView(.animation) { context in
        WelcomeMark(motion: WelcomeMotion(time: context.date.timeIntervalSinceReferenceDate))
            .frame(width: 300, height: 300)
            .padding(60)
            .background(LinearGradient(colors: WelcomeHeader.gradient, startPoint: .top, endPoint: .bottom))
    }
}
