//
//  HelpLibraryTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Atlas Help's bundled articles (board 49) and searching them.
@Suite("Help library")
struct HelpLibraryTests {
    private let library = HelpLibrary(bundle: Bundle(for: AppPreferences.self))

    @Test func everyArticleIsBundledInTheDesignsOrder() {
        #expect(library.articles.map(\.id) == HelpLibrary.order)
        #expect(library.articles(in: .start).map(\.title) == [
            "What Atlas does", "Connect App Store Connect", "How suggestions work", "Review & Push",
        ])
    }

    @Test func everyArticleIsWhole() {
        for article in library.articles {
            #expect(!article.summary.isEmpty, "\(article.id)")
            #expect(!article.blocks.isEmpty, "\(article.id)")
            #expect(!article.keywords.isEmpty, "\(article.id)")
            let missing = article.related.filter { library.article($0) == nil }
            #expect(missing.isEmpty, "\(article.id) links to \(missing)")
        }
    }

    /// Every article but What Atlas does and Keyboard Shortcuts has a place
    /// to show, as in the design.
    @Test func showMe() {
        let without = library.articles.filter { $0.showMe == nil }.map(\.id)
        #expect(without == ["what", "keys"])
        #expect(library.article("push")?.showMe == .reviewPush)
        #expect(library.article("analytics")?.showMe == .section(.analytics))
    }

    @Test func searchPutsTheBestMatchFirst() {
        #expect(library.search("vendor number").first?.id == "analytics")
        #expect(library.search("key refused").first?.id == "fix")
        #expect(library.search("Pair Claude Code").first?.id == "assistant")
        #expect(library.search("menu bar dot").first?.id == "menubar")
    }

    @Test func everyTryFindsSomething() {
        for text in HelpLibrary.tries {
            #expect(!library.search(text).isEmpty, "\(text)")
        }
    }

    @Test func nothingMatches() {
        #expect(library.search("spaceship").isEmpty)
        #expect(library.search("  ").isEmpty)
    }

    @Test func searchIgnoresCaseAccentsAndLittleWords() {
        #expect(HelpLibrary.words("How do I ADD a Language?") == ["add", "language"])
        #expect(library.search("PRÏCE increase").first?.id == "pricing")
    }

    /// The shortcuts article says what the menus really do.
    @Test func theShortcutsMatchTheSections() throws {
        let article = try #require(library.article("keys"))
        guard case let .table(_, rows) = article.blocks.first else {
            Issue.record("no table")
            return
        }
        for section in AppWorkspaceSection.allCases {
            let row = rows.first { $0.last == "⌘\(section.shortcutDigit)" }
            #expect(row != nil, "\(section)")
        }
    }
}
