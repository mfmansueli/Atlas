//
//  HelpArticleParserTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// Reading a Help article's Markdown (board 49).
@Suite("Help article parser")
struct HelpArticleParserTests {
    private let markdown = """
    ---
    id: connect
    group: start
    title: Connect App Store Connect
    summary: Atlas uses an API key.
    keywords: key, p8, issuer id
    showMe: settings:accounts
    related: privacy, fix
    ---
    ## Make the key

    1. Open **Users and Access**.
    2. Add a key.

    A paragraph
    on two lines.

    - **It suggests.** Purple.
    - You review.

    > The key stays in the Keychain.

    | An assistant can | It never can |
    | --- | --- |
    | Read listings | Push |
    """

    @Test func theFrontMatter() throws {
        let article = try #require(HelpArticleParser.article(from: markdown))
        #expect(article.id == "connect")
        #expect(article.group == .start)
        #expect(article.title == "Connect App Store Connect")
        #expect(article.summary == "Atlas uses an API key.")
        #expect(article.keywords == ["key", "p8", "issuer id"])
        #expect(article.showMe == .settings(.accounts))
        #expect(article.related == ["privacy", "fix"])
    }

    @Test func theBlocks() throws {
        let article = try #require(HelpArticleParser.article(from: markdown))
        #expect(article.blocks == [
            .heading("Make the key"),
            .steps(["Open **Users and Access**.", "Add a key."]),
            .paragraph("A paragraph on two lines."),
            .bullets(["**It suggests.** Purple.", "You review."]),
            .note("The key stays in the Keychain."),
            .table(header: ["An assistant can", "It never can"], rows: [["Read listings", "Push"]]),
        ])
    }

    /// Steps split by pictures keep counting, and a picture is a block of
    /// its own (README-Welcome's "Connect to App Store Connect").
    @Test func picturesBetweenSteps() {
        let blocks = HelpArticleParser.blocks([
            "1. **Open Users and Access.** Sign in.",
            "",
            "![Users and Access, then Integrations](help-connect-1)",
            "",
            "2. **Create a Team Key.** Pick Admin.",
            "3. **Download the key file.**",
        ])
        #expect(blocks == [
            .steps(["**Open Users and Access.** Sign in."]),
            .image(name: "help-connect-1", caption: "Users and Access, then Integrations"),
            .steps(["**Create a Team Key.** Pick Admin.", "**Download the key file.**"], start: 2),
        ])
        #expect(blocks[1].text == "Users and Access, then Integrations")
    }

    @Test func aPictureNeedsAName() {
        #expect(HelpArticleParser.image("![A caption]()") == nil)
        #expect(HelpArticleParser.image("![](help-connect-2)") == .image(name: "help-connect-2", caption: ""))
        #expect(HelpArticleParser.image("Not a picture") == nil)
    }

    @Test func theWebPageToOpen() throws {
        let article = try #require(HelpArticleParser.article(from: """
        ---
        id: connect
        group: start
        title: Get your App Store Connect key
        link: Open App Store Connect | https://appstoreconnect.apple.com/access/integrations/api
        ---
        Text
        """))
        #expect(article.link?.title == "Open App Store Connect")
        #expect(article.link?.url.absoluteString == "https://appstoreconnect.apple.com/access/integrations/api")
        #expect(HelpArticleLink("Open App Store Connect") == nil)
        #expect(HelpArticleLink("Open | http://example.com") == nil, "Only https")
        #expect(HelpArticleLink(" | https://example.com") == nil)
    }

    @Test func aTableMayStartWithAnEmptyCell() {
        #expect(HelpArticleParser.cells("| | Free | Pro |") == ["", "Free", "Pro"])
    }

    @Test func showMePlaces() {
        #expect(HelpShowMe("section:storePage") == .section(.storePage))
        #expect(HelpShowMe("reviewPush") == .reviewPush)
        #expect(HelpShowMe("settings:nowhere") == nil)
        #expect(HelpShowMe.settings(.assistants).title == "Settings → AI Assistants")
    }

    @Test func withoutFrontMatterThereIsNoArticle() {
        #expect(HelpArticleParser.article(from: "Just text") == nil)
        #expect(HelpArticleParser.article(from: "---\ntitle: No id\n---\nText") == nil)
    }
}
