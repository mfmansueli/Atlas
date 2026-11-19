//
//  UnitBezier.swift
//  Atlas
//

import Foundation

/// A CSS `cubic-bezier(x1, y1, x2, y2)` timing curve: the eased progress
/// at a moment 0…1 of the way through, as browsers work it out.
struct UnitBezier: Hashable, Sendable {
    var x1: Double
    var y1: Double
    var x2: Double
    var y2: Double

    func value(at time: Double) -> Double {
        guard time > 0 else { return 0 }
        guard time < 1 else { return 1 }
        return sampleY(solveParameter(for: time))
    }

    /// The curve's x and y at `param`, and how fast x changes there, from
    /// the polynomial's coefficients (`x = ((a·p + b)·p + c)·p`).
    private func sampleX(_ param: Double) -> Double {
        ((xCubic * param + xSquare) * param + xLinear) * param
    }

    private func sampleY(_ param: Double) -> Double {
        ((yCubic * param + ySquare) * param + yLinear) * param
    }

    private func slopeX(_ param: Double) -> Double {
        (3 * xCubic * param + 2 * xSquare) * param + xLinear
    }

    /// The parameter whose x is `time`: Newton's method, then halving when
    /// the slope is too flat.
    private func solveParameter(for time: Double) -> Double {
        var param = time
        for _ in 0..<8 {
            let error = sampleX(param) - time
            if abs(error) < 1e-7 { return param }
            let slope = slopeX(param)
            guard abs(slope) > 1e-6 else { break }
            param -= error / slope
        }
        var low = 0.0, high = 1.0
        param = time
        while high - low > 1e-7 {
            let value = sampleX(param)
            if abs(value - time) < 1e-7 { return param }
            if value < time { low = param } else { high = param }
            param = (low + high) / 2
        }
        return param
    }

    private var xLinear: Double { 3 * x1 }
    private var xSquare: Double { 3 * (x2 - x1) - xLinear }
    private var xCubic: Double { 1 - xLinear - xSquare }
    private var yLinear: Double { 3 * y1 }
    private var ySquare: Double { 3 * (y2 - y1) - yLinear }
    private var yCubic: Double { 1 - yLinear - ySquare }
}
