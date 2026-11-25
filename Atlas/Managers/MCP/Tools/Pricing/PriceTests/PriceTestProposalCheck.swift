//
//  PriceTestProposalCheck.swift
//  Atlas
//

import Foundation

/// What `propose_price_test` accepts (board 76): a region and a step for
/// one subscription, with a title and why in Atlas's voice. The assistant
/// suggests; it never starts, changes or ends a test, so any argument
/// asking to is refused, and so is a region already in a test.
enum PriceTestProposalCheck {
    /// Arguments that would act on a test instead of suggesting one.
    static let actingArguments: Set<String> = [
        "start", "startTest", "begin", "end", "endTest", "stop", "cancel", "change", "edit", "keep", "testId", "action", "push",
    ]

    /// The refusal for arguments that would start, change or end a test.
    static func actingRefusal(_ values: [String: JSONValue]) -> String? {
        guard let name = values.keys.sorted().first(where: actingArguments.contains) else { return nil }
        return String(
            localized: """
            \(name) isn’t taken: only the person starts, changes or ends a price test. Send region and step; \
            they set it up from the card in Results.
            """,
            comment: "kind:error"
        )
    }

    /// The title's and why's limits and words.
    static func textRefusal(title: String, why: String) -> String? {
        if let refusal = AssistantTextLimits.titleRefusal(title, field: "title") { return refusal }
        if let refusal = AssistantTextLimits.whyRefusal(why, field: "why") { return refusal }
        for (field, text) in [("title", title), ("why", why)] {
            let words = Set(text.lowercased().split { !$0.isLetter }.map(String.init))
            if let word = MCPPriceEvidence.bannedWords.sorted().first(where: words.contains) {
                return String(localized: "\(field) uses “\(word)”, which Atlas never writes. Say what you found plainly.", comment: "kind:error")
            }
            if text.contains("!") { return String(localized: "\(field) has an exclamation mark, which Atlas never writes.", comment: "kind:error") }
        }
        return nil
    }

    /// "europe", "Asia Pacific", "africaMiddleEast"…
    static func region(_ text: String) -> TerritoryRegion? {
        let wanted = normalized(text)
        return TerritoryRegion.allCases.first { normalized($0.rawValue) == wanted || normalized($0.title) == wanted }
    }

    /// The region's test already queued or running.
    static func busyRefusal(_ region: TerritoryRegion, tests: [PriceTest], today: Date) -> String? {
        guard let running = PriceTestRules.conflict(in: region, tests: tests, on: today) else { return nil }
        let until = running.endsOn.map { String(localized: " until \(PriceTestText.shortDate($0))", comment: "kind:error") } ?? ""
        return String(
            localized: "\(region.title) is already in the \(running.productName) price test\(until): one test per region at a time.",
            comment: "kind:error"
        )
    }

    private static func normalized(_ text: String) -> String {
        text.lowercased().filter(\.isLetter).replacingOccurrences(of: "and", with: "")
    }
}
