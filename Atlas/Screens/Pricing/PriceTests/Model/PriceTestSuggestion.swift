//
//  PriceTestSuggestion.swift
//  Atlas
//

import Foundation

/// A price test the assistant suggested (`propose_price_test`): a purple
/// card in Results with Set Up Test…, which opens the sheet filled in. The
/// person starts it; the assistant never starts, changes or ends a test.
struct PriceTestSuggestion: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var productID: String
    var region: TerritoryRegion
    var step: PriceTestStep
    /// What to test, at most 8 words ("Test suggested prices in Asia Pacific").
    var title: String
    /// The strongest evidence, one sentence, at most 110 characters.
    var why: String
    var layers: SuggestionLayers?
    /// Who suggested it, e.g. "Claude Code".
    var source: String
    var receivedAt: Date
}
