//
//  SourceTextIconTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// README-DS §13, "Icons: only Apple SF Symbols": no string in the app
/// draws an icon with a text character ("✓ Reviewed", "▶ Play", "Open ↗").
/// It scans the app's Swift sources for the characters
/// `design-tokens.json → symbol.textIcons.forbidden` lists, on every line
/// that isn't a comment. Debug scenes are left out: they're never shipped.
@Suite("Text icons in the sources")
struct SourceTextIconTests {
    /// The repository: four folders up from this file.
    private static let root = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private static func forbidden() throws -> [Character] {
        let url = root.appending(path: "Atlas/DesignSystem/Tokens/design-tokens.json")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let tokens = try #require(object as? [String: Any])
        let symbol = try #require(tokens["symbol"] as? [String: Any])
        let textIcons = try #require(symbol["textIcons"] as? [String: Any])
        let list = try #require(textIcons["forbidden"] as? [String])
        return list.compactMap(\.first)
    }

    /// "path:line: text" for each line outside a comment with a forbidden
    /// character.
    static func offenders(in text: String, path: String, forbidden: [Character]) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).enumerated().compactMap { index, line in
            let code = line.trimmingCharacters(in: .whitespaces)
            guard !code.hasPrefix("//"), !code.hasPrefix("*"), !code.hasPrefix("/*") else { return nil }
            let beforeComment = code.components(separatedBy: " // ").first ?? code
            guard beforeComment.contains(where: forbidden.contains) else { return nil }
            return "\(path):\(index + 1): \(code)"
        }
    }

    @Test func theListIsTheBoards() throws {
        let forbidden = try Self.forbidden()
        #expect(forbidden.count >= 10)
        for character: Character in ["✓", "▶", "▼", "▲", "⚠", "↗", "✕"] {
            #expect(forbidden.contains(character), "\(character)")
        }
    }

    @Test func noLineOfTheAppDrawsAnIconWithText() throws {
        let forbidden = try Self.forbidden()
        let app = Self.root.appending(path: "Atlas")
        let enumerator = try #require(FileManager.default.enumerator(at: app, includingPropertiesForKeys: nil))
        var offenders: [String] = []
        var scanned = 0
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let path = url.path(percentEncoded: false).replacingOccurrences(of: Self.root.path(percentEncoded: false), with: "")
            guard !path.hasPrefix("Atlas/Debug/") else { continue }
            scanned += 1
            offenders += try Self.offenders(in: String(contentsOf: url, encoding: .utf8), path: path, forbidden: forbidden)
        }
        #expect(scanned > 500, "The sources were found")
        #expect(offenders.isEmpty, "Use Image(systemName:) or Label: \(offenders.joined(separator: "\n"))")
    }

    @Test func commentsMayNameTheCharacters() {
        let text = """
        /// "✓ Reviewed" was the old pill.
        Pill(text: "Reviewed", systemImage: "checkmark") // was ✓
        Button("▶ Play") {}
        """
        let found = Self.offenders(in: text, path: "Example.swift", forbidden: ["✓", "▶"])
        #expect(found == ["Example.swift:3: Button(\"▶ Play\") {}"])
    }
}
