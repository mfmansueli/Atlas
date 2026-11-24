//
//  GetProductPagesTool+Pages.swift
//  Atlas
//

import Foundation

// One page as get_product_pages lists it: what App Store Connect has (or
// the draft made in Atlas), its own content per language, its numbers
// against the default page's, and what's queued in Review & Push on top.
extension GetProductPagesTool {
    static func pageJSON(_ page: ProductPage, in state: MCPProductPages, withTexts: Bool) -> [String: JSONValue] {
        var object: [String: JSONValue] = [
            "id": .string(page.id),
            "name": .string(page.name),
            "state": .string(page.isDraft ? "draft" : page.state.rawValue),
            "visible": .bool(state.isVisible(page)),
        ]
        if let url = page.url { object["url"] = .string(url.absoluteString) }
        if let next = page.nextVersion { object["newVersion"] = ["number": .int(next.number), "state": .string(next.state.rawValue)] }
        if !page.deepLink.isEmpty { object["deepLink"] = .string(page.deepLink) }
        object.merge(languagesJSON(page, in: state, withTexts: withTexts)) { $1 }
        if let numbers = state.numbers(of: page) {
            object["numbers"] = numbersJSON(numbers, reference: state.defaultNumbers)
        } else if state.numbers != nil, !page.isDraft {
            object["numbers"] = .string(ProductPageNumbersText.noNumbers(for: page))
        }
        if let blocker = state.textBlocker(page) {
            object["takesTexts"] = false
            object["why"] = .string(blocker)
        } else {
            object["takesTexts"] = true
            if let note = state.newVersionNote(page) { object["newVersionNote"] = .string(note) }
        }
        if let draft = state.draft(of: page) {
            object["draft"] = draftJSON(draft, in: state)
        } else if let queued = queuedJSON(state.edits(of: page)) {
            object["queued"] = queued
        }
        if let brief = state.archive.brief(named: page.name) {
            object["brief"] = [
                "audience": .string(brief.audience), "screens": .string(brief.screens), "by": .string(brief.source),
                "screenshotsAdded": .bool(page.locales.contains { page.localization($0)?.hasOwnScreenshots == true }),
            ]
        }
        return object
    }

    /// `languages` (each with something of its own) and `showsDefaultIn`
    /// (the default page's languages with nothing of their own).
    private static func languagesJSON(_ page: ProductPage, in state: MCPProductPages, withTexts: Bool) -> [String: JSONValue] {
        var languages: [String: JSONValue] = [:]
        var showsDefault: [JSONValue] = []
        let codes = state.defaultPage.locales + page.locales.filter { !state.defaultPage.locales.contains($0) }
        for code in codes {
            guard let localization = page.localization(code), localization.hasOwnContent else {
                showsDefault.append(.string(code))
                continue
            }
            var language: [String: JSONValue] = [:]
            if !localization.hasOwnText {
                language["textFromDefault"] = true
            } else if withTexts {
                language["promotionalText"] = .string(localization.promotionalText)
            } else {
                language["ownText"] = true
            }
            if !localization.keywords.isEmpty { language["keywords"] = .array(localization.keywords.map(JSONValue.string)) }
            if localization.hasOwnScreenshots { language["ownScreenshots"] = true }
            languages[code] = .object(language)
        }
        return ["languages": .object(languages), "showsDefaultIn": .array(showsDefault)]
    }

    /// The last 28 days, and the download rate against the default page's.
    /// Under 200 page views the rate isn't given: it's too few to compare.
    static func numbersJSON(_ numbers: ProductPageNumbers, reference: ProductPageNumbers?) -> JSONValue {
        var object: [String: JSONValue] = [
            "impressions": .int(numbers.impressions),
            "pageViews": .int(numbers.pageViews),
            "downloads": .int(numbers.downloads),
        ]
        if let rate = numbers.downloadRate, numbers.pageViews >= ProductPageNumbers.fewestViewsToCompare {
            object["downloadRate"] = .double((rate * 10).rounded() / 10)
        }
        if let reference, let comparison = ProductPageComparison(page: numbers, reference: reference) {
            object["vsDefault"] = comparisonJSON(comparison)
        } else if reference == nil, numbers.pageViews < ProductPageNumbers.fewestViewsToCompare {
            object["vsDefault"] = comparisonJSON(.tooFewViews(numbers.pageViews))
        }
        // Where the page's link is used: campaign links and referrers.
        if !numbers.arrivals.isEmpty {
            object["arrivals"] = .array(numbers.arrivals.prefix(10).map { arrival in
                .object([
                    "kind": .string(arrival.kind.rawValue), "name": .string(arrival.name),
                    "pageViews": .int(arrival.pageViews), "downloads": .int(arrival.downloads),
                ])
            })
        }
        return .object(object)
    }

    private static func comparisonJSON(_ comparison: ProductPageComparison) -> JSONValue {
        switch comparison {
        case .aboutTheSame: ["result": "aboutTheSame"]
        case let .above(points): ["result": "above", "points": .double((points * 10).rounded() / 10)]
        case let .below(points): ["result": "below", "points": .double((points * 10).rounded() / 10)]
        case let .tooFewViews(views):
            ["result": "tooFewToCompare", "pageViews": .int(views), "needs": .int(ProductPageNumbers.fewestViewsToCompare)]
        }
    }

    /// What's waiting in Review & Push for a page in App Store Connect;
    /// nil when nothing is.
    static func queuedJSON(_ edits: ProductPageEdits) -> JSONValue? {
        guard !edits.isEmpty else { return nil }
        var object: [String: JSONValue] = ["changes": .int(edits.count)]
        if !edits.texts.isEmpty { object["promotionalText"] = .object(edits.texts.mapValues(JSONValue.string)) }
        if !edits.keywords.isEmpty { object["keywords"] = .object(edits.keywords.mapValues { .array($0.map(JSONValue.string)) }) }
        if let link = edits.deepLink { object["deepLink"] = .string(link) }
        if let name = edits.name { object["name"] = .string(name) }
        if let visible = edits.isVisible { object["visible"] = .bool(visible) }
        if edits.isDeleted { object["deleted"] = true }
        return .object(object)
    }

    /// A draft made in Atlas: what it starts from, its note, and the one
    /// change in Review & Push that creates it.
    private static func draftJSON(_ draft: ProductPageDraft, in state: MCPProductPages) -> JSONValue {
        let changeID = state.builder.newPageChangeID(draftID: draft.id)
        var object: [String: JSONValue] = [
            "startsFrom": startJSON(draft.start),
            "changeId": .string(changeID),
            "by": .string(draft.source.title),
        ]
        if !draft.note.isEmpty { object["note"] = .string(draft.note) }
        if let suggestion = draft.suggestionID { object["fromSuggestion"] = .string(suggestion) }
        if let blocked = state.changes.first(where: { $0.id == changeID })?.blockedReason { object["blockedReason"] = .string(blocked) }
        return .object(object)
    }

    /// `defaultPage`, `empty`, or `{copyOf, name}`.
    static func startJSON(_ start: ProductPageStart) -> JSONValue {
        switch start {
        case .defaultPage: "defaultPage"
        case .empty: "empty"
        case let .copy(pageID, name): ["copyOf": .string(pageID), "name": .string(name)]
        }
    }
}
