//
//  GetProductPagesTool+Suggestions.swift
//  Atlas
//

import Foundation

// The suggestions kept on this Mac, as get_product_pages lists them: the
// pages and promotional texts assistants sent, each with its status (open,
// notOffered when App Review's rules stopped it, dismissed by the person)
// and who sent it, so an assistant suggests none of them twice.
extension GetProductPagesTool {
    /// `{pages, texts}`; texts only for `pageID` when it's given.
    static func suggestionsJSON(_ state: MCPProductPages, pageID: ProductPage.ID?) -> JSONValue {
        let archive = state.archive
        let texts = archive.textSuggestions.filter { pageID == nil || $0.pageID == pageID }
        return [
            "pages": .array(archive.pageSuggestions.map { pageSuggestionJSON($0, isDismissed: archive.dismissed.contains($0.id)) }),
            "texts": .array(texts.map { textSuggestion in
                textSuggestionJSON(
                    textSuggestion, pageName: state.page(textSuggestion.pageID)?.name, isDismissed: archive.dismissed.contains(textSuggestion.id)
                )
            }),
        ]
    }

    static func pageSuggestionJSON(_ suggestion: ProductPageSuggestion, isDismissed: Bool) -> JSONValue {
        var object: [String: JSONValue] = [
            "id": .string(suggestion.id),
            "name": .string(suggestion.name),
            "status": isDismissed ? "dismissed" : "open",
            "by": .string(suggestion.source),
            "suggestedAt": .string(suggestion.createdAt.formatted(.iso8601)),
        ]
        guard !isDismissed else { return .object(object) }
        object["audience"] = .string(suggestion.audience)
        object["reason"] = .string(suggestion.reason)
        object["evidence"] = MCPProductPageEvidence.json(suggestion.evidence)
        object["startFrom"] = startJSON(suggestion.start ?? .defaultPage)
        let texts = suggestion.promotionalTexts.filter { !$0.value.isEmpty }
        if !texts.isEmpty { object["promotionalText"] = .object(texts.mapValues(JSONValue.string)) }
        let keywords = suggestion.keywords.filter { !$0.value.isEmpty }
        if !keywords.isEmpty { object["keywords"] = .object(keywords.mapValues { .array($0.map(JSONValue.string)) }) }
        if let refused = suggestion.notOfferedTexts, !refused.isEmpty {
            object["notOffered"] = .array(refused.map { ["locale": .string($0.locale), "text": .string($0.text), "why": .string($0.refusal)] })
        }
        if !suggestion.screens.isEmpty { object["screens"] = .string(suggestion.screens) }
        if !suggestion.deepLink.isEmpty { object["deepLink"] = .string(suggestion.deepLink) }
        return .object(object)
    }

    static func textSuggestionJSON(_ suggestion: ProductPageTextSuggestion, pageName: String?, isDismissed: Bool) -> JSONValue {
        let status = isDismissed ? "dismissed" : suggestion.isRefused ? "notOffered" : "open"
        var object: [String: JSONValue] = [
            "pageId": .string(suggestion.pageID),
            "locale": .string(suggestion.locale),
            "status": .string(status),
            "by": .string(suggestion.source),
            "suggestedAt": .string(suggestion.createdAt.formatted(.iso8601)),
        ]
        if let pageName { object["page"] = .string(pageName) }
        guard !isDismissed else { return .object(object) }
        object["text"] = .string(suggestion.text)
        if !suggestion.reason.isEmpty { object["reason"] = .string(suggestion.reason) }
        if suggestion.isRefused { object["why"] = .string(suggestion.refusal) }
        return .object(object)
    }
}
