//
//  ProposeProductPageEditTool.swift
//  Atlas
//

import Foundation

/// `propose_product_page_edit`: changes an existing custom product page in
/// App Store Connect as its editor does: its name, deep link, keywords per
/// language and whether it's visible, or deletes it. Each change is built by
/// `ProductPageChangeBuilder` and waits in Review & Push; deleting waits
/// until the person accepts it there.
struct ProposeProductPageEditTool: MCPTool {
    var store = ProductPagesStore.shared
    var analytics = AnalyticsStore.shared

    /// The arguments, typed apart so the definition type-checks quickly.
    private static let properties: [String: JSONValue] = MCPToolDefinition.withLayers([
        "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
        "pageId": MCPToolDefinition.string("A page in App Store Connect, by its id from get_product_pages (not a draft-…)."),
        "name": MCPToolDefinition.string("A new reference name, one no other page has."),
        "deepLink": MCPToolDefinition.string("A complete link the app opens (check it in the project), or \"\" to remove it."),
        "keywords": [
            "type": "object", "additionalProperties": ["type": "array", "items": ["type": "string"]],
            "description": "Locale → the page's whole keyword list there: approved keywords no other page uses (get_product_pages).",
        ],
        "visible": ["type": "boolean", "description": "An approved page only: true shows it on the App Store, false hides it."],
        "delete": ["type": "boolean", "description": "true deletes the page, alone; the person accepts it in Review & Push first."],
        "reason": MCPToolDefinition.why("Why, for the person."),
    ])

    let definition = MCPToolDefinition(
        name: "propose_product_page_edit",
        title: "Propose changes to a product page",
        description: """
        Changes a custom product page that's in App Store Connect, as its editor in Custom Product Pages does: \
        name, deepLink, keywords {locale: [keyword]} (the page's whole list in that language: only the approved \
        version's keywords, and one another page uses is refused with its name), visible (approved pages only; hiding \
        sends its link to the default page) or delete: true (alone; it waits until the person accepts it in Review & \
        Push, and is refused while the person has changes for that page). Keywords and the deep link of an approved \
        page are refused until the person presses Edit… on it (a new version); a page with App Review takes nothing. Every problem is \
        refused at once with how to fix it. Each change waits in Review & Push (status "queued"); nothing reaches App \
        Store Connect until the person pushes. Texts are propose_product_page_texts; drafts made in Atlas change there.
        """,
        inputSchema: MCPToolDefinition.schema(Self.properties, required: ["appId", "pageId", "reason"]),
        proposalKind: .storeText
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let pageID = try arguments.string("pageId")
        let section = "\(app.name) · Custom Product Pages"
        guard context.allows(.storeText) else { return .refused(MCPProposalKind.storeText.refusal, target: section) }
        let state = try await MCPProductPages.load(app: app, workspace: context.workspace, store: store, analytics: analytics)
        guard let page = state.page(pageID) else {
            if state.isQueuedForDeletion(pageID) {
                return .refused(String(localized: "That page is deleted when the person pushes."), target: section)
            }
            throw MCPToolError.notFound(String(localized: "\(app.name) has no product page “\(pageID)”. Use the ids get_product_pages lists."))
        }
        let target = "\(section) · \(page.name)"
        let reason = try arguments.string("reason")
        if let problem = AssistantTextLimits.whyRefusal(reason, field: "reason") { return .refused(problem, target: target) }
        if let refusal = Self.refusal(for: page, state: state) { return .refused(refusal, target: target) }
        let edit = try MCPProductPageEdit(arguments)
        guard !edit.isEmpty else {
            throw MCPToolError.invalidArgument(name: "name", expected: String(localized: "one of name, deepLink, keywords, visible or delete"))
        }
        let plan = edit.plan(page: page, state: state, queue: context.workspace.changes, source: context.source)
        guard plan.problems.isEmpty else { return .refused(plan.problems.joined(separator: " "), target: target) }
        let layers = try SuggestionLayers(details: arguments.optionalString("details") ?? reason, confidence: arguments.layers()?.confidence)
        Self.apply(plan, deleting: edit.delete ? page.id : nil, builder: state.builder, layers: layers, in: context)
        guard !plan.changes.isEmpty else {
            let note = String(localized: "That’s what the page has already; nothing was queued.")
            return MCPToolOutcome(result: ["status": "unchanged", "note": .string(note)], isError: false, logLines: [.init(target: target, outcome: .read)])
        }
        let result: JSONValue = [
            "status": "queued",
            "changeIds": .array(plan.changes.map { .string($0.id) }),
            "pageId": .string(page.id),
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    /// Why the page takes no edit: a draft made in Atlas, a key that can't
    /// write, a version with App Review.
    private static func refusal(for page: ProductPage, state: MCPProductPages) -> String? {
        guard page.isDraft else { return state.textBlocker(page) }
        return String(localized: """
        “\(page.name)” is a draft made in Atlas: the person changes it in Custom Product Pages, or send \
        propose_product_page again with its name to replace your suggestion.
        """)
    }

    /// Queues the plan's changes and drops the assistant's own that are
    /// back to what the page has; deleting first drops every change of
    /// its own for the page.
    private static func apply(
        _ plan: MCPProductPageEdit.Plan,
        deleting pageID: ProductPage.ID?,
        builder: ProductPageChangeBuilder,
        layers: SuggestionLayers,
        in context: MCPToolContext
    ) {
        let queue = context.workspace.changes
        if let pageID {
            queue.discardAll { builder.isChange($0, of: pageID) && $0.source == context.source }
        }
        for change in plan.changes {
            queue.upsert(change)
        }
        for id in plan.discards where queue.change(id: id)?.source == context.source {
            queue.discard(id: id)
        }
        queue.attach(layers.nonEmpty, to: plan.changes.map(\.id))
    }
}
