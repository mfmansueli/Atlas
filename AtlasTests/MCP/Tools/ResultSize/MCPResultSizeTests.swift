//
//  MCPResultSizeTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// How big `get_in_app_events` and `get_listing` are on the DEBUG data
/// (Lumen Journal's sample events and Store Page), as the text an MCP
/// client receives, with and without their filters. The sizes go in the
/// "sizes.txt" attachment. Before the filters, on the same data, the
/// whole answers were 26,340 and 10,752 characters.
@MainActor
@Suite("MCP · result sizes")
struct MCPResultSizeTests {
    private func size(_ tool: some MCPTool, _ arguments: [String: JSONValue]) async throws -> Int {
        let workspace = MCPTestFixtures.workspace()
        let context = MCPToolContext(workspace: workspace, clientName: "Claude Code")
        return try await tool.call(MCPToolArguments(arguments), in: context).result.jsonString().count
    }

    private var events: GetInAppEventsTool {
        GetInAppEventsTool(store: DebugInAppEventsData.store(), directory: EventArtworkTestFiles.directory(), linkClaims: ProjectLinkClaimsCenter())
    }

    private static let app: JSONValue = "Lumen Journal"
    private static let winter = JSONValue.string(DebugInAppEventsData.winterID)

    @Test func filtersMakeTheAnswersSmaller() async throws {
        let all = try await size(events, ["appId": Self.app, "include": ["all"]])
        let standard = try await size(events, ["appId": Self.app])
        let oneEvent = try await size(events, ["appId": Self.app, "eventId": Self.winter])
        let oneEventTexts = try await size(events, ["appId": Self.app, "eventId": Self.winter, "include": ["texts"]])
        let oneEventReview = try await size(events, ["appId": Self.app, "eventId": Self.winter, "include": ["review", "deepLinkCheck"]])
        let design = try await size(events, ["appId": Self.app, "eventId": Self.winter, "include": ["design"]])

        let listing = try await size(GetListingTool(), ["appId": Self.app])
        let whatsNew = try await size(GetListingTool(), ["appId": Self.app, "fields": ["whatsNew"]])
        let short = try await size(GetListingTool(), ["appId": Self.app, "fields": ["name", "subtitle", "keywords", "promotionalText"]])
        let urls = try await size(GetListingTool(), ["appId": Self.app, "fields": ["urls"]])
        let german = try await size(GetListingTool(), ["appId": Self.app, "locales": ["de-DE"]])

        let lines = [
            "get_in_app_events include all \(all)",
            "get_in_app_events default \(standard)",
            "get_in_app_events eventId \(oneEvent)",
            "get_in_app_events eventId texts \(oneEventTexts)",
            "get_in_app_events eventId review+deepLinkCheck \(oneEventReview)",
            "get_in_app_events eventId design \(design)",
            "get_listing all \(listing)",
            "get_listing fields whatsNew \(whatsNew)",
            "get_listing fields name+subtitle+keywords+promotionalText \(short)",
            "get_listing fields urls \(urls)",
            "get_listing locales de-DE \(german)",
        ]
        Attachment.record(lines.joined(separator: "\n") + "\n", named: "sizes.txt")

        #expect(standard < all)
        #expect(oneEvent < standard)
        #expect(oneEventTexts < oneEvent)
        #expect(whatsNew < listing)
        #expect(short < listing)
        #expect(urls < listing)
    }
}
#endif
