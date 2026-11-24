//
//  ProposeProductPageTextsTool.swift
//  Atlas
//

import Foundation

/// `propose_product_page_texts`: an assistant suggests promotional texts
/// for languages of a page in App Store Connect or a draft made in Atlas.
/// Each shows on the page's language as the usual suggestion block (Now,
/// Suggested, Dismiss, Use and Edit, Accept); one App Review would reject is
/// kept as Not offered, with its words marked and why, and can't be
/// accepted. Accepted texts wait in Review & Push.
struct ProposeProductPageTextsTool: MCPTool {
    var store = ProductPagesStore.shared
    var analytics = AnalyticsStore.shared
    var reviews = ReviewsStore.shared

    static let reasonLimit = AssistantTextLimits.why

    let definition = MCPToolDefinition(
        name: "propose_product_page_texts",
        title: "Suggest a product page's promotional texts",
        description: """
        Suggests promotional text for languages of a custom product page, a page in App Store Connect or a draft made in \
        Atlas (ids from get_product_pages; only pages with takesTexts). `texts` is [{locale, promotionalText, reason, \
        details, confidence, gloss}]: ≤170 characters, written for the page's audience in that language, `reason` one \
        sentence for the person on why it reads this way (at most \(AssistantTextLimits.why) characters; the call's \
        `reason` when left out; the rest goes in `details`, the call's when left out), `confidence` how sure you are \
        (1–3), `gloss` what the text means in English. `evidence` [{source, detail}] is optional, from \
        analytics, reviews or keywords as in propose_product_page. Each shows on that language of the page with Dismiss, \
        Use and Edit, and Accept; sending a language again replaces its waiting suggestion. Skipped, with why: a \
        language the app doesn't have, an empty text or one over 170, the page's own text again, or a language whose \
        text already waits in Review & Push (`queued` in get_product_pages). An approved page's suggestion shows once \
        the person presses Edit… there, which makes a new version. \(ProductPageTextRules.summary) Accepted texts wait \
        in Review & Push; nothing reaches App Store Connect until the person pushes.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPToolDefinition.withLayers([
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "pageId": MCPToolDefinition.string("The page's id from get_product_pages: a page in App Store Connect or a draft (draft-…)."),
                "texts": [
                    "type": "array", "description": "One per language.",
                    "items": MCPToolDefinition.schema(
                        MCPToolDefinition.withLayers([
                            "locale": MCPToolDefinition.string("An App Store locale code the app has, e.g. de-DE."),
                            "promotionalText": MCPToolDefinition.string("The text, ≤170 characters."),
                            "reason": MCPToolDefinition.why("Optional: why it reads this way, for the person."),
                        ], gloss: true),
                        required: ["locale", "promotionalText"]
                    ),
                ],
                "reason": MCPToolDefinition.why("Why, for every text without its own, e.g. “German reviews say gesperrt for the lock.”"),
                "evidence": ["type": "array", "items": MCPProductPageEvidence.itemSchema, "description": "What it's based on. Optional."],
            ]),
            required: ["appId", "pageId", "texts", "reason"]
        ),
        proposalKind: .storeText
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let pageID = try arguments.string("pageId")
        guard context.allows(.storeText) else { return .refused(MCPProposalKind.storeText.refusal, target: "\(app.name) · Custom Product Pages") }
        let state = try await MCPProductPages.load(app: app, workspace: context.workspace, store: store, analytics: analytics)
        guard let page = state.page(pageID) else {
            if state.isQueuedForDeletion(pageID) {
                return .refused(String(localized: "That page is deleted when the person pushes: it takes no texts."), target: "\(app.name) · Custom Product Pages")
            }
            throw MCPToolError.notFound(String(localized: "\(app.name) has no product page “\(pageID)”. Use the ids get_product_pages lists."))
        }
        let target = "\(app.name) · Custom Product Pages · \(page.name)"
        if let blocker = state.textBlocker(page) { return .refused(blocker, target: target) }
        let reason = try arguments.string("reason")
        let evidence = try MCPProductPageEvidence.read(arguments.values["evidence"])
        var problems = [AssistantTextLimits.whyRefusal(reason, field: "reason")].compactMap(\.self)
        problems += MCPProductPageEvidence.problems(
            evidence, app: app, keywordsChosen: page.keywordCount > 0, hasApprovedVersion: state.defaultPage.hasApprovedVersion,
            analytics: analytics, reviews: reviews
        )
        guard problems.isEmpty else {
            return .refused(problems.joined(separator: " "), target: target, details: ["problems": .array(problems.map(JSONValue.string))])
        }
        let read = try Self.read(
            arguments.array("texts"), page: page, state: state, why: (reason, arguments.layers()), evidence: evidence,
            source: context.clientName
        )
        guard !read.kept.isEmpty else {
            return .refused(String(localized: "No language could be kept."), target: target, details: ["skipped": .array(read.skipped)])
        }
        store.add(read.kept, for: app.id)
        var result: [String: JSONValue] = [
            "status": "suggested",
            "languages": .array(read.kept.filter { !$0.isRefused }.map { .string($0.locale) }),
            "skipped": .array(read.skipped),
            "showsIn": .string(String(localized: "Custom Product Pages (⌘4) → \(page.name)")),
        ]
        if !read.notOffered.isEmpty { result["notOffered"] = .array(read.notOffered) }
        if let note = state.newVersionNote(page) { result["newVersionNote"] = .string(note) }
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [MCPToolOutcome.LogLine(target: target, outcome: .proposed)])
    }

    /// The suggestions to keep (offered and Not offered), what was left out
    /// and why, and the Not offered ones' rules.
    private static func read(
        _ items: [JSONValue], page: ProductPage, state: MCPProductPages, why call: (reason: String, layers: SuggestionLayers?),
        evidence: [SuggestionEvidence], source: String
    ) throws -> (kept: [ProductPageTextSuggestion], skipped: [JSONValue], notOffered: [JSONValue]) {
        var kept: [ProductPageTextSuggestion] = []
        var skipped: [JSONValue] = []
        var notOffered: [JSONValue] = []
        let queued = state.edits(of: page).texts
        let keptEvidence = evidence.isEmpty ? nil : evidence
        for item in items {
            guard let code = item["locale"]?.stringValue, let text = item["promotionalText"]?.stringValue ?? item["text"]?.stringValue else {
                throw MCPToolError.invalidArgument(name: "texts", expected: String(localized: "{locale, promotionalText, reason} objects"))
            }
            let own = (item["reason"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let why = own.isEmpty ? call.reason : own
            let callLayers = call.layers
            let ownLayers = try MCPToolArguments(item.objectValue ?? [:]).layers()
            let layers = SuggestionLayers(
                details: ownLayers?.details ?? callLayers?.details, confidence: ownLayers?.confidence ?? callLayers?.confidence,
                gloss: ownLayers?.gloss
            ).nonEmpty
            func skip(_ message: String) { skipped.append(["locale": .string(code), "reason": .string(message)]) }
            if let refusal = AssistantTextLimits.whyRefusal(why, field: "Its reason") {
                skip(refusal)
                continue
            }
            let check = MCPPromotionalText.check(locale: code, text: text, in: state)
            if let locale = check.locale, kept.contains(where: { $0.locale == locale }) {
                skip(String(localized: "Sent twice: the first is kept."))
                continue
            }
            switch check {
            case let .problem(problem): skip(problem)
            case .empty: skip(String(localized: "The text is empty."))
            case let .offered(locale, checked), let .notOffered(locale, checked, _):
                if checked == state.text(of: page, locale: locale) {
                    skip(String(localized: "That's the page's text already; leave it."))
                } else if !page.isDraft, queued[locale] != nil {
                    skip(String(localized: "A text for this language waits in Review & Push (queued in get_product_pages); leave it."))
                } else if case let .notOffered(_, _, issues) = check {
                    kept.append(MCPPromotionalText.refused(
                        pageID: page.id, locale: locale, text: checked, issues: issues, reason: why, source: source, evidence: keptEvidence,
                        layers: layers
                    ))
                    notOffered.append(MCPPromotionalText.notOfferedJSON(locale: locale, issues: issues))
                } else {
                    kept.append(ProductPageTextSuggestion(
                        pageID: page.id, locale: locale, text: checked, reason: why, source: source, evidence: keptEvidence, layers: layers
                    ))
                }
            }
        }
        return (kept, skipped, notOffered)
    }
}
