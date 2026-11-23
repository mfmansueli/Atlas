//
//  GlobeBand.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// An ellipse round the globe, as the icon draws its band and thin orbit:
/// centred on the globe, `rx` × `ry`, turned by `rotation`, in the icon's
/// 1024-unit square with y pointing down. Its front half passes below the
/// centre, its back half above. `path(_:from:to:)` follows the curve by
/// its length, as an SVG dash does, so a stretch keeps its length all the
/// way round.
struct GlobeBand: Hashable, Sendable {
    enum Half: Hashable, Sendable {
        /// Left end → bottom → right end.
        case front
        /// Right end → top → left end.
        case back
    }

    var rx: Double
    var ry: Double
    /// Degrees; negative turns it anticlockwise on screen, like SVG's
    /// `rotate(-24)`.
    var rotation: Double

    /// The menu bar icon's band.
    static let menuBar = GlobeBand(rx: 470, ry: 150, rotation: -24)
    /// The app icon's band, which the welcome header's tiles ride.
    static let icon = GlobeBand(rx: 440, ry: 130, rotation: -24)

    private static let samples = 96

    /// The point at angle `theta` (radians) on the unturned ellipse.
    func point(theta: Double) -> CGPoint {
        CGPoint(x: rx * cos(theta), y: ry * sin(theta))
    }

    /// The angle a half is at, `fraction` of its length along.
    func theta(on half: Half, atLength fraction: Double) -> Double {
        let lengths = cumulativeLengths(half)
        guard let total = lengths.last, total > 0 else { return angle(on: half, at: fraction) }
        let target = min(max(fraction, 0), 1) * total
        let index = lengths.firstIndex { $0 >= target } ?? lengths.count - 1
        guard index > 0 else { return angle(on: half, at: 0) }
        let before = lengths[index - 1], after = lengths[index]
        let local = after > before ? (target - before) / (after - before) : 0
        let step = 1 / Double(Self.samples)
        return angle(on: half, at: (Double(index - 1) + local) * step)
    }

    /// The part of `half` from `from` to `end` of its length (0…1), turned.
    func path(_ half: Half, from: Double = 0, to end: Double = 1) -> CGPath {
        let path = CGMutablePath()
        let start = theta(on: half, atLength: from), finish = theta(on: half, atLength: end)
        let steps = max(2, Int((abs(finish - start) / .pi) * Double(Self.samples)))
        let transform = CGAffineTransform(rotationAngle: rotation * .pi / 180)
        for step in 0...steps {
            let theta = start + (finish - start) * Double(step) / Double(steps)
            let point = point(theta: theta).applying(transform)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    /// Where a point on the unturned ellipse lands once turned.
    func turned(_ point: CGPoint) -> CGPoint {
        point.applying(CGAffineTransform(rotationAngle: rotation * .pi / 180))
    }

    /// The angle `parameter` (0…1) of the way along a half, by angle.
    private func angle(on half: Half, at parameter: Double) -> Double {
        switch half {
        case .front: .pi * (1 - parameter)
        case .back: -.pi * parameter
        }
    }

    private func cumulativeLengths(_ half: Half) -> [Double] {
        var lengths = [0.0]
        var previous = point(theta: angle(on: half, at: 0))
        for step in 1...Self.samples {
            let next = point(theta: angle(on: half, at: Double(step) / Double(Self.samples)))
            lengths.append(lengths[step - 1] + hypot(next.x - previous.x, next.y - previous.y))
            previous = next
        }
        return lengths
    }
}
