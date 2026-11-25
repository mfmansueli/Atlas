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

    /// Light and dark as the app resolves them from its asset catalogue.
    @Test func everyColourMatchesInLightAndDark() throws {
        let colors = try section("color")
        #expect(colors.count >= 35)
        let appearances: [(String, NSAppearance.Name)] = [("light", .aqua), ("dark", .darkAqua)]
        for (name, value) in colors {
            let variants = try #require(value as? [String: String], "\(name)")
            let color = try #require(NSColor(named: Self.assetName(name), bundle: .main), "\(name) is a Color Set")
            for (key, appearanceName) in appearances {
                let expected = try #require(variants[key], "\(name).\(key)")
                let actual = try #require(Self.hex(of: color, in: appearanceName))
                #expect(Self.matches(actual, expected), "\(name).\(key): \(actual) in the asset catalogue, \(expected) in the JSON")
            }
        }
    }

    /// All four variants as the Color Sets write them. AppKit resolves the
    /// high contrast ones only with Increase Contrast on, so they're read
    /// from the catalogue's source next to this file.
    @Test func everyColourMatchesTheColorSetsInAllFourVariants() throws {
        let colors = try section("color")
        let catalogue = URL(filePath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Atlas/SupportFiles/Assets.xcassets")
        let sets = try Self.colorSets(in: catalogue)
        #expect(Set(sets.keys) == Set(colors.keys.map(Self.assetName)), "the JSON names every Color Set, and only those")
        for (name, value) in colors {
            let variants = try #require(value as? [String: String], "\(name)")
            let source = try #require(sets[Self.assetName(name)], "\(name) is a Color Set")
            for key in ["light", "dark", "highContrastLight", "highContrastDark"] {
                let expected = try #require(variants[key], "\(name).\(key)")
                let actual = try #require(source[key], "\(name).\(key) in the Color Set")
                #expect(Self.matches(actual, expected), "\(name).\(key): \(actual) in the Color Set, \(expected) in the JSON")
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
        // §13: the sections have no colour sets of their own any more,
        // only system colours (`symbol`).
        #expect(colors.keys.allSatisfy { !$0.hasPrefix("section") })
    }

    // MARK: - Symbols (§13)

    @Test func everySectionHasTheBoardsSymbolAndColour() throws {
        let sections = try #require(try section("symbol")["section"] as? [String: [String: String]])
        #expect(Set(sections.keys) == Set(AppWorkspaceSection.allCases.map(\.rawValue)))
        for section in AppWorkspaceSection.allCases {
            let entry = try #require(sections[section.rawValue], "\(section)")
            #expect(section.style.symbol == entry["symbol"], "\(section) symbol")
            #expect(section.style.tint.rawValue == entry["tint"], "\(section) tint")
            #expect(section.systemImage == section.style.symbol, "\(section)")
        }
    }

    @Test func everySettingsPaneHasTheBoardsSymbolAndColour() throws {
        let panes = try #require(try section("symbol")["settings"] as? [String: [String: String]])
        #expect(Set(panes.keys) == Set(SettingsPane.allCases.map(\.rawValue)))
        for pane in SettingsPane.allCases {
            let entry = try #require(panes[pane.rawValue], "\(pane)")
            #expect(pane.style.symbol == entry["symbol"], "\(pane) symbol")
            #expect(pane.style.tint.rawValue == entry["tint"], "\(pane) tint")
        }
    }

    @Test func everyStatusHasItsSymbolAndColour() throws {
        let statuses = try #require(try section("symbol")["status"] as? [String: [String: String]])
        #expect(Set(statuses.keys) == Set(StatusSymbol.allCases.map(\.rawValue)))
        for status in StatusSymbol.allCases {
            let entry = try #require(statuses[status.rawValue], "\(status)")
            #expect(status.symbol == entry["symbol"], "\(status) symbol")
            #expect(status.tint.rawValue == entry["tint"], "\(status) tint")
        }
    }

    /// Every tint the JSON names is a `SymbolTint`.
    @Test func everyTintIsASymbolTint() throws {
        let symbols = try section("symbol")
        for group in ["section", "settings", "status"] {
            let entries = try #require(symbols[group] as? [String: [String: String]], "\(group)")
            for (name, entry) in entries {
                #expect(SymbolTint(rawValue: entry["tint"] ?? "") != nil, "\(group).\(name)")
            }
        }
    }

    /// The board's main symbols, written out so the JSON can't drift from
    /// README-DS §13 either.
    @Test func theReadmesSymbolsAreTheSwifts() {
        #expect(AppWorkspaceSection.overview.style == SectionStyle(symbol: "square.grid.2x2", tint: .systemGray))
        #expect(AppWorkspaceSection.productPages.style == SectionStyle(symbol: "rectangle.stack", tint: .systemTeal))
        #expect(AppWorkspaceSection.nominations.style == SectionStyle(symbol: "rosette", tint: .systemBrown))
        #expect(AppWorkspaceSection.reviews.style == SectionStyle(symbol: "star", tint: .systemYellow))
        #expect(AppWorkspaceSection.analytics.style == SectionStyle(symbol: "chart.bar", tint: .systemIndigo))
        #expect(SettingsPane.assistants.style.tint == .ai, "the one purple pane")
        #expect(StatusSymbol.error.symbol == "exclamationmark.circle.fill")
        // No section is drawn with a filled symbol any more.
        #expect(AppWorkspaceSection.allCases.allSatisfy { !$0.style.symbol.hasSuffix(".fill") })
        // Purple is AI's: no section is.
        #expect(AppWorkspaceSection.allCases.allSatisfy { $0.style.tint != .ai })
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
            "layout": MotionTiming.layout, "tick": MotionTiming.tick, "breathe": MotionTiming.breathe,
            "sentLift": MotionTiming.sentLift, "sentFlyX": MotionTiming.sentFlyX, "sentFlyY": MotionTiming.sentFlyY,
            "sentLand": MotionTiming.sentLand, "sentRing": MotionTiming.sentRing,
        ]
        for (name, token) in tokens {
            let entry = try #require(motion[name] as? [String: Any], "motion.\(name)")
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
        #expect(MotionTiming.breathe == MotionToken(duration: 1.5, curve: .bezier(x1: 0.42, y1: 0, x2: 0.58, y2: 1)))
        // Board 80: sent to Review & Push.
        #expect(MotionTiming.sentLift == MotionToken(duration: 0.12, curve: .bezier(x1: 0.2, y1: 0.7, x2: 0.2, y2: 1)))
        #expect(MotionTiming.sentFlyX == MotionToken(duration: 0.6, curve: .bezier(x1: 0.25, y1: 0.7, x2: 0.35, y2: 1)))
        #expect(MotionTiming.sentFlyY == MotionToken(duration: 0.6, curve: .bezier(x1: 0.65, y1: 0, x2: 0.85, y2: 0.55)))
        #expect(MotionTiming.sentLand.curve == .spring(response: 0.5, dampingFraction: 0.5))
        #expect(MotionTiming.sentRing == MotionToken(duration: 0.7, curve: .easeOut))
    }

    // MARK: - Helpers

    private static func assetName(_ token: String) -> String {
        token == "accent" ? "AccentColor" : token
    }

    /// Every `.colorset` under `catalogue`: its four variants as hex, a
    /// missing dark falling back to light and a missing high contrast to
    /// its plain variant, as the asset catalogue does.
    private static func colorSets(in catalogue: URL) throws -> [String: [String: String]] {
        var sets: [String: [String: String]] = [:]
        let files = FileManager.default.enumerator(at: catalogue, includingPropertiesForKeys: nil)
        while let url = files?.nextObject() as? URL {
            guard url.pathExtension == "colorset" else { continue }
            let data = try Data(contentsOf: url.appending(path: "Contents.json"))
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            var variants: [String: String] = [:]
            for entry in object?["colors"] as? [[String: Any]] ?? [] {
                let looks = (entry["appearances"] as? [[String: String]] ?? []).compactMap { $0["value"] }.sorted()
                let key = switch looks {
                case []: "light"
                case ["dark"]: "dark"
                case ["high"]: "highContrastLight"
                case ["dark", "high"]: "highContrastDark"
                default: "other"
                }
                guard let components = (entry["color"] as? [String: Any])?["components"] as? [String: String] else { continue }
                variants[key] = hex(components)
            }
            variants["dark"] = variants["dark"] ?? variants["light"]
            variants["highContrastLight"] = variants["highContrastLight"] ?? variants["light"]
            variants["highContrastDark"] = variants["highContrastDark"] ?? variants["dark"]
            sets[url.deletingPathExtension().lastPathComponent] = variants
        }
        return sets
    }

    /// A Color Set's components ("0x7A", "0.541" or "255") as hex.
    private static func hex(_ components: [String: String]) -> String {
        func byte(_ text: String?) -> Int {
            guard let text else { return 0 }
            if text.hasPrefix("0x") { return Int(text.dropFirst(2), radix: 16) ?? 0 }
            if text.contains(".") { return Int(((Double(text) ?? 0) * 255).rounded()) }
            return Int(text) ?? 0
        }
        var text = String(format: "#%02X%02X%02X", byte(components["red"]), byte(components["green"]), byte(components["blue"]))
        let alpha = Int(((Double(components["alpha"] ?? "1") ?? 1) * 255).rounded())
        if alpha != 255 { text += String(format: "%02X", alpha) }
        return text
    }

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
