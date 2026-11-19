//
//  AtlasIconGradientTests.swift
//  AtlasTests
//

import AppKit
import SwiftUI
import Testing
@testable import Atlas

/// The places that draw the app icon themselves use `Atlas.icon`'s fill:
/// the sRGB values in its `icon.json`.
@Suite("Atlas icon gradient")
struct AtlasIconGradientTests {
    /// `fill-specializations` in Atlas.icon/icon.json, top to bottom.
    static let iconLight: [[Double]] = [[0.12157, 0.76078, 1.00000], [0.03922, 0.36078, 0.94902]]
    static let iconDark: [[Double]] = [[0.08235, 0.56471, 0.90980], [0.03922, 0.24706, 0.72157]]

    @Test func lightMatchesTheIcon() {
        expect(AtlasIconGradient.light, toMatch: Self.iconLight)
    }

    @Test func darkMatchesTheIconsDarkAppearance() {
        expect(AtlasIconGradient.dark, toMatch: Self.iconDark)
    }

    @Test func eachAppearanceGetsItsOwnGradient() {
        expect(AtlasIconGradient.colors(for: .light), toMatch: Self.iconLight)
        expect(AtlasIconGradient.colors(for: .dark), toMatch: Self.iconDark)
    }

    @Test func theWelcomeHeaderKeepsTheBrightGradient() {
        expect(WelcomeHeader.gradient, toMatch: Self.iconLight)
    }

    private func expect(_ colors: [Color], toMatch expected: [[Double]], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(colors.count == expected.count, sourceLocation: sourceLocation)
        for (color, components) in zip(colors, expected) {
            let srgb = NSColor(color).usingColorSpace(.sRGB)
            let actual = [srgb?.redComponent, srgb?.greenComponent, srgb?.blueComponent].map { Double($0 ?? -1) }
            for (value, want) in zip(actual, components) {
                #expect(abs(value - want) < 0.002, "\(actual) ≠ \(components)", sourceLocation: sourceLocation)
            }
        }
    }
}
