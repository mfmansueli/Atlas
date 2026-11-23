//
//  DesignTokensTests.swift
//  AtlasTests
//

import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Atlas

/// Rule zero (README — Design system): one source of design truth. The
/// Swift tokens (the asset catalogue behind `Palette`, `AtlasTextStyle`,
/// `Spacing`, `Radius`, `MotionTiming`) hold the same values as
/// `design-tokens.json`, so they can't drift apart.
@MainActor
@Suite("Design tokens")
struct DesignTokensTests {
    private let tokens: [String: Any]

    init() throws {
        let url = try #require(Bundle.main.url(forResource: "design-tokens", withExtension: "json"), "design-tokens.json is in the app")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        tokens = try #require(object as? [String: Any])
    }

    private func section(_ name: String) throws -> [String: Any] {
        try #require(tokens[name] as? [String: Any])
    }

    // MARK: - Colour

    @Test func everyColourMatchesInLightDarkAndHighContrast() throws {
        let colors = try section("color")
        #expect(colors.count >= 50)
        let appearances: [(String, NSAppearance.Name)] = [
            ("light", .aqua), ("dark", .darkAqua),
            ("highContrastLight", .accessibilityHighContrastAqua), ("highContrastDark", .accessibilityHighContrastDarkAqua),
        ]
        for (name, value) in colors {
            let variants = try #require(value as? [String: String], "\(name)")
            let assetName = name == "accent" ? "AccentColor" : name
            let color = try #require(NSColor(named: assetName, bundle: .main), "\(name) is a Color Set")
            for (key, appearanceName) in appearances {
                let expected = try #require(variants[key], "\(name).\(key)")
                let actual = try #require(Self.hex(of: color, in: appearanceName))
                #expect(Self.matches(actual, expected), "\(name).\(key): \(actual) in the asset catalogue, \(expected) in the JSON")
            }
        }
    }

    @Test func theReadmesNamedValuesAreTheJSONs() throws {
        let colors = try section("color")
        func light(_ name: String) -> String? { (colors[name] as? [String: String])?["light"] }
        func dark(_ name: String) -> String? { (colors[name] as? [String: String])?["dark"] }
        // README §1's table.
        #expect(light("accent") == "#0071E3")
        #expect(dark("accent") == "#0A72E8")
        #expect(light("accentText") == "#0066CC")
        #expect(light("label2") == "#6B6B70")
        #expect(light("label3") == "#9A9AA0")
        #expect(light("ai") == "#7A35B0")
        #expect(dark("ai") == "#D4A3FF")
        #expect(light("aiFill") == "#8A3CD6")
        #expect(dark("aiFill") == "#B98CFF")
        #expect(light("ok") == "#1D7A3A")
        #expect(light("warn") == "#7A5600")
        #expect(light("err") == "#C8102E")
        #expect(light("brandTop") == "#1FC2FF")
        #expect(light("brandBottom") == "#0A5CF2")
        // README §2's section tiles, top → bottom.
        #expect(light("sectionScreenshotsTop") == "#F57A35")
        #expect(light("sectionScreenshots") == "#CE5619")
        #expect(light("sectionReviewsTop") == "#F7BE1A")
        #expect(light("sectionEvents") == "#C03B69")
    }

    // MARK: - Type

    @Test func theTypeScaleMatches() throws {
        let type = try section("type")
        #expect(type.count == AtlasTextStyle.allCases.count)
        for style in AtlasTextStyle.allCases {
            let entry = try #require(type[style.rawValue] as? [String: Any], "\(style)")
            #expect((entry["size"] as? Double).map { CGFloat($0) } == style.size, "\(style) size")
            #expect((entry["lineHeight"] as? Double).map { CGFloat($0) } == style.lineHeight, "\(style) line height")
            #expect(entry["weight"] as? String == style.weightName, "\(style) weight")
        }
    }

    /// The nine system styles are macOS's own: their sizes are the system's
    /// at the default text size.
    @Test func theSystemStylesAreTheSystemsSizes() {
        for style in AtlasTextStyle.allCases {
            guard let system = style.systemStyle else { continue }
            #expect(NSFont.preferredFont(forTextStyle: system).pointSize == style.size, "\(style)")
        }
    }

    // MARK: - Spacing and radius

    @Test func spacingMatches() throws {
        let spacing = try section("spacing")
        let swift: [String: CGFloat] = [
            "tiny": Spacing.tiny, "xxSmall": Spacing.xxSmall, "xSmall": Spacing.xSmall, "small": Spacing.small,
            "medium": Spacing.medium, "large": Spacing.large, "xLarge": Spacing.xLarge, "xxLarge": Spacing.xxLarge,
            "xxxLarge": Spacing.xxxLarge,
        ]
        #expect(Set(spacing.keys.filter { !$0.hasPrefix("$") }) == Set(swift.keys))
        for (name, value) in swift {
            #expect((spacing[name] as? Double).map { CGFloat($0) } == value, "spacing.\(name)")
        }
    }

    @Test func radiiMatch() throws {
        let radius = try section("radius")
        let swift: [String: CGFloat] = [
            "flag": Radius.flag, "badge": Radius.badge, "menuRow": Radius.menuRow, "field": Radius.field,
            "banner": Radius.banner, "card": Radius.card, "popover": Radius.popover, "sheet": Radius.sheet,
        ]
        #expect(Set(radius.keys) == Set(swift.keys))
        for (name, value) in swift {
            #expect((radius[name] as? Double).map { CGFloat($0) } == value, "radius.\(name)")
        }
    }

    // MARK: - Motion

    @Test func motionMatches() throws {
        let motion = try section("motion")
        let tokens: [String: MotionToken] = [
            "fast": MotionTiming.fast, "base": MotionTiming.base, "slow": MotionTiming.slow, "step": MotionTiming.step,
            "layout": MotionTiming.layout, "tick": MotionTiming.tick,
        ]
        for (name, token) in tokens {
            let entry = try #require(motion[name] as? [String: Any], name)
            #expect(Self.curve(entry) == token.curve, "motion.\(name) curve")
            if case .spring = token.curve { continue }
            #expect(entry["duration"] as? Double == token.duration, "motion.\(name) duration")
        }
        let stagger = try #require(motion["stagger"] as? [String: Any])
        #expect(stagger["delay"] as? Double == MotionTiming.staggerDelay)
        #expect(stagger["limit"] as? Int == MotionTiming.staggerLimit)
        #expect((motion["sweep"] as? [String: Any])?["duration"] as? Double == MotionTiming.sweep)
        #expect((motion["trailLeg"] as? [String: Any])?["duration"] as? Double == MotionTiming.trailLeg)
    }

    /// The README's own numbers, so the JSON can't drift from it either.
    @Test func theMotionTokensAreTheReadmes() {
        #expect(MotionTiming.fast == MotionToken(duration: 0.15, curve: .easeOut))
        #expect(MotionTiming.base == MotionToken(duration: 0.25, curve: .bezier(x1: 0.2, y1: 0.7, x2: 0.2, y2: 1)))
        #expect(MotionTiming.slow == MotionToken(duration: 0.4, curve: .bezier(x1: 0.2, y1: 0.7, x2: 0.2, y2: 1)))
        #expect(MotionTiming.step == MotionToken(duration: 0.5, curve: .bezier(x1: 0.65, y1: 0, x2: 0.35, y2: 1)))
        #expect(MotionTiming.layout.curve == .spring(response: 0.35, dampingFraction: 0.8))
        #expect(MotionTiming.tick.curve == .spring(response: 0.45, dampingFraction: 0.6))
        #expect(MotionTiming.tick.spring != nil)
        #expect(MotionTiming.base.spring == nil)
        #expect(MotionTiming.staggerDelay == 0.07)
        #expect(MotionTiming.staggerLimit == 6)
        #expect(MotionTiming.sweep == 2.8)
    }

    // MARK: - Helpers

    private static func curve(_ entry: [String: Any]) -> MotionCurve? {
        if let spring = entry["spring"] as? [String: Double], let response = spring["response"], let damping = spring["dampingFraction"] {
            return .spring(response: response, dampingFraction: damping)
        }
        if entry["curve"] as? String == "easeOut" { return .easeOut }
        if let points = entry["curve"] as? [Double], points.count == 4 {
            return .bezier(x1: points[0], y1: points[1], x2: points[2], y2: points[3])
        }
        return nil
    }

    /// `#RRGGBB`, or `#RRGGBBAA` when not opaque, in sRGB.
    private static func hex(of color: NSColor, in appearanceName: NSAppearance.Name) -> String? {
        guard let appearance = NSAppearance(named: appearanceName) else { return nil }
        var result: String?
        appearance.performAsCurrentDrawingAppearance {
            guard let srgb = color.usingColorSpace(.sRGB) else { return }
            func byte(_ value: CGFloat) -> Int { Int((value * 255).rounded()) }
            var text = String(format: "#%02X%02X%02X", byte(srgb.redComponent), byte(srgb.greenComponent), byte(srgb.blueComponent))
            if byte(srgb.alphaComponent) != 255 { text += String(format: "%02X", byte(srgb.alphaComponent)) }
            result = text
        }
        return result
    }

    /// Equal, give or take one step per channel from rounding.
    private static func matches(_ lhs: String, _ rhs: String) -> Bool {
        func channels(_ hex: String) -> [Int] {
            var value = String(hex.dropFirst())
            if value.count == 6 { value += "FF" }
            return stride(from: 0, to: value.count, by: 2).compactMap { index in
                let start = value.index(value.startIndex, offsetBy: index)
                return Int(value[start..<value.index(start, offsetBy: 2)], radix: 16)
            }
        }
        let left = channels(lhs)
        let right = channels(rhs)
        return left.count == right.count && zip(left, right).allSatisfy { abs($0 - $1) <= 1 }
    }
}
