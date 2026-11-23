//
//  ProductPageTestProposal.swift
//  Atlas
//

import Foundation

/// A Product Page Optimization test an assistant proposed over MCP
/// (`propose_page_test`): its name, the placement it changes, the share of
/// visitors, the treatment (the run's variant or assets already in the
/// app's library), the languages, and why. It waits in Review & Push's
/// header and search card until the person opens it in “Test with Product
/// Page Optimization…”, prefilled, and creates the test, or dismisses it.
/// Kept in the app's `ScreenshotExtras`, beside the variant.
struct ProductPageTestProposal: Codable, Hashable, Sendable, Identifiable {
    /// "pt-3f2a9c1b".
    var id: String
    /// The test's name in App Store Connect.
    var name: String
    var placement: ProductPageTestPlacement
    /// The share of the page's visitors who see the treatment, in percent.
    var trafficProportion: Int
    var treatment: ProductPageTestTreatmentSource
    /// App Store Connect locale codes, primary language first.
    var locales: [String]
    /// Sends it to App Review once it's made; off, it stays a draft.
    var startsTest = false
    /// Why, in a sentence the person reads.
    var reason: String
    /// What it's based on: "analytics: search conversion 2.1% vs 3.4%".
    var evidence: [String] = []
    /// The assistant that proposed it, e.g. "Claude Code".
    var client: String
    var receivedAt: Date
    var status: ProductPageTestProposalStatus = .pending
    /// What happened once the person made it: the outcome's line.
    var outcome: String?
    var decidedAt: Date?
    /// Details and how sure, beside the reason; nil in proposals saved
    /// before.
    var layers: SuggestionLayers?

    static let maxName = 64
    static let maxReason = AssistantTextLimits.why
    static let trafficRange = 1...100

    /// A new proposal's ID.
    static func makeID() -> String {
        "pt-" + UUID().uuidString.lowercased().prefix(8)
    }

    var isOpen: Bool { status == .pending }

    /// "Header · 50% of visitors · 3 languages".
    var summary: String {
        let languages = locales.count == 1 ? String(localized: "1 language") : String(localized: "\(locales.count) languages")
        return String(localized: "\(placement.title) · \(trafficProportion)% of visitors · \(languages)")
    }
}
