//
//  HelpLibraryTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Atlas Help's bundled articles (board 49) and searching them.
@Suite("Help library")
@MainActor
struct HelpLibraryTests {
    private let library = HelpLibrary(bundle: Bundle(for: AppPreferences.self))

    @Test func everyArticleIsBundledInTheDesignsOrder() {
        #expect(library.articles.map(\.id) == HelpLibrary.order)
        #expect(library.articles(in: .start).map(\.title) == [
            "What Atlas does", "Connect to App Store Connect", "How suggestions work", "Review & Push",
        ])
    }

    /// Show Me How on Connect opens it (README-Welcome): four steps, each
    /// with its picture, the tip for people who don't see Integrations, and
    /// App Store Connect to open beside it.
    @Test func getYourAppStoreConnectKey() throws {
        let article = try #require(library.article(ConnectBeforeYouStart.helpArticleID))
        #expect(article.title == "Connect to App Store Connect")
        #expect(article.summary == "Keep this window next to your browser. It takes about two minutes.")
        let steps = article.blocks.compactMap { block -> [String]? in
            if case let .steps(items, _) = block { return items }
            return nil
        }.flatMap(\.self)
        #expect(steps.count == 4)
        #expect(steps.first?.hasPrefix("**Open Users and Access, then Integrations.**") == true)
        let starts = article.blocks.compactMap { block -> Int? in
            if case let .steps(_, start) = block { return start }
            return nil
        }
        #expect(starts == [1, 2, 3, 4])
        let pictures = article.blocks.filter { if case .image = $0 { true } else { false } }
        #expect(pictures.count == 4)
        #expect(article.blocks.last == HelpBlock.note(
            "**Don’t see Integrations?** Only the Account Holder or an Admin can make keys. Ask them for one."
        ))
        #expect(article.link?.url == ConnectBeforeYouStart.integrationsURL)
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
        #expect(library.search("make screenshots for this page").first?.id == "pages")
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
            let row = rows.first { $0.last == section.shortcutText }
            #expect(row != nil, "\(section)")
        }
    }
}
