//
//  MCPProductPagesFixtures.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The product page tools against Lumen Journal's DEBUG pages (boards
/// 50–55): five pages in App Store Connect, Private diary made in Atlas and
/// waiting in Review & Push, two suggested pages, German and Japanese texts
/// suggested for Private diary, the last 28 days' numbers and the reviews.
@MainActor
struct MCPProductPagesFixtures {
    typealias Data = DebugProductPagesData
    typealias PageID = DebugProductPagesData.PageID

    static let appID = DebugProductPagesData.appID
    static let client = "Claude Code"

    var store = DebugProductPagesData.store()
    var analytics = DebugProductPagesData.analytics()
    var reviews = DebugReviewsData.store()
    var changes = ChangeQueue(changes: DebugProductPagesData.pendingChanges)
    var services: any ProductPagesServices = DebugProductPagesServices()

    var getTool: GetProductPagesTool { GetProductPagesTool(store: store, analytics: analytics) }
    var pageTool: ProposeProductPageTool { ProposeProductPageTool(store: store, analytics: analytics, reviews: reviews) }
    var textsTool: ProposeProductPageTextsTool { ProposeProductPageTextsTool(store: store, analytics: analytics, reviews: reviews) }

    var builder: ProductPageChangeBuilder { ProductPageChangeBuilder(appID: Self.appID) }

    func call(
        _ tool: some MCPTool, _ arguments: [String: JSONValue], allowed: Set<MCPProposalKind> = Set(MCPProposalKind.allCases),
        client: String = MCPProductPagesFixtures.client
    ) async throws -> MCPToolOutcome {
        var workspace = MCPTestFixtures.workspace(changes: changes)
        workspace.services.productPages = services
        let context = MCPToolContext(workspace: workspace, clientName: client, allowedProposals: allowed)
        return try await tool.call(MCPToolArguments(arguments), in: context)
    }

    /// get_product_pages' page with this name.
    func page(_ name: String, in result: JSONValue) throws -> JSONValue {
        try #require(result["pages"]?.arrayValue?.first { $0["name"]?.stringValue == name })
    }

    /// A page Claude Code suggests, with evidence Atlas can show.
    static func pageArguments(
        name: String = "Weekly look back", texts: [String: JSONValue] = ["en-US": "One calm page for your week: your moments, your mood."],
        keywords: [String: JSONValue] = ["en-US": ["reflection"]], evidence: JSONValue = [["source": "analytics", "detail": "Product Page test"]]
    ) -> [String: JSONValue] {
        [
            "appId": "Lumen Journal", "name": .string(name),
            "audience": "For people who want a look back at their week, not a daily habit",
            "reason": "Your product page test “Weekly Reflections first” downloads 18% better.",
            "evidence": evidence, "keywords": .object(keywords), "promotionalText": .object(texts),
        ]
    }

    /// propose_product_page_texts' arguments for one page.
    static func textsArguments(_ pageID: String, _ texts: [JSONValue], evidence: JSONValue? = nil) -> [String: JSONValue] {
        var arguments: [String: JSONValue] = [
            "appId": "Lumen Journal", "pageId": .string(pageID), "texts": .array(texts), "reason": "From the English text.",
        ]
        if let evidence { arguments["evidence"] = evidence }
        return arguments
    }

    static func text(_ locale: String, _ text: String, reason: String? = nil) -> JSONValue {
        var object: [String: JSONValue] = ["locale": .string(locale), "promotionalText": .string(text)]
        if let reason { object["reason"] = .string(reason) }
        return .object(object)
    }
}
#endif
