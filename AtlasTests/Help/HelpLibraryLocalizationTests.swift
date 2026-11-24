//
//  HelpLibraryLocalizationTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Help articles are localized resources: each article in the app's
/// language when it has one, else in English.
@Suite("Help library localization")
struct HelpLibraryLocalizationTests {
    private let appBundle = Bundle(for: AppPreferences.self)

    @Test func everyArticleIsAnEnglishLocalizedResource() {
        let urls = HelpLibrary.articleURLs(in: appBundle, localization: "en")
        #expect(urls.count == HelpLibrary.order.count)
        for url in urls {
            #expect(url.deletingLastPathComponent().lastPathComponent == "en.lproj", "\(url.path)")
        }
    }

    @Test func aLanguageWithoutArticlesFallsBackToEnglish() {
        let library = HelpLibrary(bundle: appBundle, localization: "de")
        #expect(library.articles.map(\.id) == HelpLibrary.order)
        #expect(library.article("keys")?.title == "Keyboard shortcuts")
        #expect(!library.search("vendor number").isEmpty)
    }

    @Test func aTranslatedArticleReplacesItsEnglishOneOnly() throws {
        let bundle = try Self.bundle(files: [
            "en.lproj/help-a.md": Self.article(id: "a", title: "Apples"),
            "en.lproj/help-b.md": Self.article(id: "b", title: "Bananas"),
            "de.lproj/help-a.md": Self.article(id: "a", title: "Äpfel"),
        ])
        defer { try? FileManager.default.removeItem(at: bundle.bundleURL) }
        let german = HelpLibrary(bundle: bundle, localization: "de")
        #expect(german.articles.count == 2)
        #expect(german.article("a")?.title == "Äpfel")
        #expect(german.article("b")?.title == "Bananas")
        #expect(german.search("Äpfel").map(\.id) == ["a"])
        let english = HelpLibrary(bundle: bundle, localization: "en")
        #expect(english.article("a")?.title == "Apples")
    }

    @Test func anArticleOutsideAnyLocalizationStillCounts() throws {
        let bundle = try Self.bundle(files: ["help-c.md": Self.article(id: "c", title: "Cherries")])
        defer { try? FileManager.default.removeItem(at: bundle.bundleURL) }
        #expect(HelpLibrary(bundle: bundle, localization: "fr").article("c")?.title == "Cherries")
    }

    // MARK: - Fixtures

    private static func article(id: String, title: String) -> String {
        """
        ---
        id: \(id)
        group: atlas
        title: \(title)
        summary: About \(title).
        keywords: \(title.lowercased())
        ---
        \(title) are fruit.
        """
    }

    /// A bundle folder holding `files` (relative path → text).
    private static func bundle(files: [String: String]) throws -> Bundle {
        let root = FileManager.default.temporaryDirectory.appending(path: "HelpLibrary-\(UUID().uuidString).bundle")
        for (path, text) in files {
            let url = root.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        return try #require(Bundle(url: root))
    }
}
