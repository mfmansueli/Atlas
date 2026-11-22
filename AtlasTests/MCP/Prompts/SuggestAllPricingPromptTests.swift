//
//  SuggestAllPricingPromptTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Suggest Everything reads prices too: the app's own, every subscription
/// and in-app purchase's, beside what the project sells, and proposes what
/// differs with the price tools.
@MainActor
@Suite("suggest_all · prices")
struct SuggestAllPricingPromptTests {
    private static let priceTools = [
        "get_app_price_and_availability", "get_subscriptions", "get_prices", "get_price_points",
        "propose_prices", "propose_subscription", "propose_app_price", "propose_availability",
    ]

    @Test func suggestAllComparesPricesWithTheProject() {
        let text = MCPPrompt.suggestAll.message(app: "Lumen Journal")["messages"]?.arrayValue?.first?["content"]?["text"]?.stringValue ?? ""
        for tool in Self.priceTools {
            #expect(text.contains(tool), "\(tool)")
        }
        #expect(text.contains(".storekit"))
        #expect(text.contains("file:line"))
        #expect(text.contains("never push"))
    }

    @Test func thePriceToolsAreAllServed() {
        let names = MCPToolbox.standard.toolNames
        for tool in Self.priceTools {
            #expect(names.contains(tool), "\(tool)")
        }
    }

    @Test func theServerInstructionsMentionProjectPrices() {
        for tool in ["get_app_price_and_availability", "propose_prices", "propose_app_price", "propose_availability"] {
            #expect(MCPEndpoint.instructions.contains(tool), "\(tool)")
        }
    }
}
