//
//  ProposeProductPageTool.swift
//  Atlas
//

import Foundation

/// `propose_product_page`: an assistant suggests a whole custom product
/// page, kept on this Mac (`ProductPagesStore`) and shown in Product Pages
/// with its reason and evidence, Dismiss and Accept. Accepting makes a draft
/// page in Atlas; nothing reaches App Store Connect until the person pushes
/// it, and only they submit it or make it visible.
struct ProposeProductPageTool: MCPTool {
    var store = ProductPagesStore.shared
    var analytics = AnalyticsStore.shared
    var reviews = ReviewsStore.shared

    let definition = MCPToolDefinition(
        name: "propose_product_page",
        title: "Suggest a custom product page",
        description: """
        Suggests a custom product page for an app, shown in Atlas's Product Pages (⌘4) with Dismiss and Accept; \
        accepting makes a draft page in Atlas. Read get_product_pages first. Send `name` (the page's reference name, \
        one no page has), `audience` (who it's for and what it should do, ≤200 characters), `reason` (why, from the \
        evidence, one sentence, at most \(AssistantTextLimits.why) characters), optional `details` (the rest, at most \
        \(AssistantTextLimits.details)) and `confidence` (1–3), and `evidence` [{source, detail}], each with the number \
        that points to this page: analytics \
        (get_analytics_funnel, or get_analytics_breakdown by source, language, territory or productPage), reviews (read \
        with get_reviews) or keywords (the approved version's ones it chooses); a page without evidence Atlas can show \
        isn't listed, so it's refused. `keywords` {locale: [keyword]} only from get_product_pages' \
        keywords.<locale>.free, the ones the page's audience searches: a keyword leads to one page, so one another page \
        uses is refused with its name. `promotionalText` {locale: text} in the app's languages, ≤170 characters each, \
        written for that audience; the others show the default page's. `startFrom` is defaultPage (its screenshots, App \
        Previews and text), empty, or a page's id to copy (all but its keywords). `screens` is what the page's \
        screenshots should show, in order, [{screen, caption}] or a sentence: real screens of the app. Search results show \
        the first three, not the promotional text; they're the page's brief, which the person makes into the page's \
        own set with Make Screenshots for This Page. `deepLink` is a complete link the app opens (check it in the project). Every problem is refused at once \
        with how to fix it: \
        an unknown language, a text over 170, a keyword not approved or taken, a name taken, no room under the 70 \
        pages (drafts, hidden and rejected ones count, and so do suggested pages waiting). Sending a name you \
        suggested again replaces that suggestion; a dismissed one is refused. \(ProductPageTextRules.summary) \
        You can't push, submit or make a page visible: the person does.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPToolDefinition.withLayers([
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "name": MCPToolDefinition.string("The page's reference name, e.g. “Weekly reflections”: shown in Atlas and App Store Connect."),
                "audience": MCPToolDefinition.string("Who it's for and what it should do, e.g. “People who want a look back at their week”."),
                "reason": MCPToolDefinition.why("Why, from the evidence."),
                "evidence": ["type": "array", "items": MCPProductPageEvidence.itemSchema, "description": "What it's based on, one or more."],
                "keywords": [
                    "type": "object", "additionalProperties": ["type": "array", "items": ["type": "string"]],
                    "description": "Locale → keywords from get_product_pages' keywords.<locale>.free.",
                ],
                "promotionalText": [
                    "type": "object", "additionalProperties": ["type": "string"],
                    "description": "Locale → promotional text (≤170 characters), in each of the app's languages.",
                ],
                "startFrom": MCPToolDefinition.string("defaultPage (default), empty, or the id of a page in App Store Connect to copy."),
                "screens": [
                    "type": "array", "items": MCPToolDefinition.schema(
                        ["screen": MCPToolDefinition.string("The screen."), "caption": MCPToolDefinition.string("Its caption, optional.")],
                        required: ["screen"]
                    ),
                    "description": "The screenshots in the order the page should show them, for Autopilot.",
                ],
                "deepLink": MCPToolDefinition.string("Where the app opens from this page, e.g. https://example.app/reflections. Optional."),
            ]),
            required: ["appId", "name", "audience", "reason", "evidence"]
        ),
        proposalKind: .storeText
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let name = try arguments.optionalString("name") ?? ""
        let target = "\(app.name) · Product Pages · \(name)"
        guard context.allows(.storeText) else { return .refused(MCPProposalKind.storeText.refusal, target: target) }
        let state = try await MCPProductPages.load(app: app, workspace: context.workspace, store: store, analytics: analytics)
        if state.archive.keyCannotChange {
            return .refused(String(localized: """
            The API key can read \(app.name)'s product pages but not change them, so the person couldn't accept a page. \
            Tell them their key needs the Admin, App Manager or Marketing role.
            """), target: target)
        }
        let proposal = try ProductPageProposal.make(arguments, state: state, source: context.clientName, analytics: analytics, reviews: reviews)
        guard proposal.problems.isEmpty else {
            return .refused(
                proposal.problems.joined(separator: " "), target: target,
                details: ["problems": .array(proposal.problems.map(JSONValue.string))]
            )
        }
        store.add(proposal.suggestion, for: app.id)
        return MCPToolOutcome(
            result: Self.result(proposal, state: state, store: store),
            isError: false,
            logLines: [MCPToolOutcome.LogLine(target: target, outcome: .proposed)]
        )
    }

    private static func result(_ proposal: ProductPageProposal, state: MCPProductPages, store: ProductPagesStore) -> JSONValue {
        let suggestion = proposal.suggestion
        var object: [String: JSONValue] = [
            "status": "suggested",
            "suggestionId": .string(suggestion.id),
            "replaced": .bool(proposal.replaces != nil),
            "name": .string(suggestion.name),
            "languages": .array(suggestion.promotionalTexts.keys.sorted().map(JSONValue.string)),
            "keywords": .object(suggestion.keywords.mapValues { .array($0.map(JSONValue.string)) }),
            "showsIn": .string(String(localized: "Product Pages (⌘4) → Suggested pages")),
            "pageLimit": state.reading(store).limitJSON,
        ]
        if !proposal.notOffered.isEmpty {
            object["notOffered"] = .array(proposal.notOffered.map { MCPPromotionalText.notOfferedJSON(locale: $0.locale, issues: $0.issues) })
            object["note"] = .string(String(localized: """
            The page is suggested without those texts: those languages show the default page's until you send the page \
            again under the same name with new ones.
            """))
        }
        if !proposal.languagesWithoutText.isEmpty {
            object["languagesWithoutText"] = .array(proposal.languagesWithoutText.map(JSONValue.string))
        }
        return .object(object)
    }
}
