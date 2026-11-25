//
//  ProposePageReviewActionTool.swift
//  Atlas
//

import Foundation

/// `propose_page_review_action`: suggests what to do with a custom product
/// page and App Review: submit it, cancel its submission while it waits, or
/// start a new version of an approved page. Checked like the page's own
/// buttons; it waits on the page's editor, and only the person does it.
struct ProposePageReviewActionTool: MCPTool {
    var store = ProductPagesStore.shared
    var analytics = AnalyticsStore.shared
    var suggestions = ProductPageReviewSuggestionStore.shared

    let definition = MCPToolDefinition(
        name: "propose_page_review_action",
        title: "Suggest a product page's review step",
        description: """
        Suggests what to do with a custom product page and App Review, as its editor offers it: action submit (a page \
        that isn't with App Review or approved; its changes waiting in Review & Push are pushed first, then Submit \
        for Review opens), cancelSubmission (while it's Waiting for Review) or newVersion (an approved page: Edit… \
        starts the next version, so texts, keywords and the deep link can change; App Review approves it before it \
        replaces the live one). why says why in one sentence. It waits on the page's editor; only the person submits, \
        cancels or starts the version, with the page's own button. withdraw: true takes it back.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPToolDefinition.withLayers([
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "pageId": MCPToolDefinition.string("The page's id from get_product_pages."),
                "action": [
                    "type": "string", "enum": .array(ProductPageReviewAction.allCases.map { .string($0.rawValue) }),
                    "description": "submit, cancelSubmission or newVersion.",
                ],
                "why": MCPToolDefinition.why("Why, for the person."),
                "withdraw": ["type": "boolean", "description": "true: take back your suggestion for this page; nothing else is read."],
            ]),
            required: ["appId", "pageId"]
        ),
        proposalKind: .release
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let pageID = try arguments.string("pageId")
        let section = String(localized: "\(app.name) · Custom Product Pages", comment: "kind:other")
        guard context.allows(.release) else { return .refused(MCPProposalKind.release.refusal, target: section) }
        if try arguments.optionalBool("withdraw") == true {
            guard suggestions.suggestion(for: app.id, pageID: pageID)?.client == context.clientName else {
                return .refused(String(localized: "No suggestion of yours waits on this page.", comment: "kind:error"), target: section)
            }
            suggestions.remove(for: app.id, pageID: pageID)
            return MCPToolOutcome(result: ["status": "withdrawn"], isError: false, logLines: [.init(target: section, outcome: .proposed)])
        }
        guard let action = try ProductPageReviewAction(rawValue: arguments.string("action")) else {
            throw MCPToolError.invalidArgument(name: "action", expected: "submit, cancelSubmission or newVersion")
        }
        let why = try arguments.string("why")
        let layers = try arguments.layers()
        let state = try await MCPProductPages.load(app: app, workspace: context.workspace, store: store, analytics: analytics)
        guard let page = state.page(pageID) else {
            throw MCPToolError.notFound(String(localized: "\(app.name) has no product page “\(pageID)”. Use the ids get_product_pages lists."))
        }
        let target = "\(section) · \(page.name)"
        if state.archive.keyCannotChange {
            let reason = String(
                localized: "The API key can read product pages but not change them. The person adds an Admin or App Manager key.", comment: "kind:error"
            )
            return .refused(reason, target: target)
        }
        let pending = state.builder.changes(of: page.id, in: state.changes).count
        let canCancel = context.workspace.services.productPages.canCancelSubmission
        if let refusal = Self.refusal(action, page: page, canCancel: canCancel) { return .refused(refusal, target: target) }
        suggestions.suggest(ProductPageReviewSuggestion(appID: app.id, pageID: page.id, action: action, why: why, client: context.clientName, layers: layers))
        var result: [String: JSONValue] = [
            "status": "suggested",
            "pageId": .string(page.id),
            "action": .string(action.rawValue),
            "note": .string(String(localized: "It waits on the page; the person uses \(action.buttonTitle)")),
        ]
        if action == .submit, pending > 0 || page.isDraft {
            result["pushesFirst"] = .int(pending)
        }
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    /// Why `action` doesn't fit the page now; nil when it does.
    static func refusal(_ action: ProductPageReviewAction, page: ProductPage, canCancel: Bool) -> String? {
        let state = page.isDraft ? nil : page.editing?.state
        let name = page.name
        switch action {
        case .submit:
            switch state {
            case nil, .prepareForSubmission?, .readyForReview?, .rejected?: return nil
            case .waitingForReview?, .inReview?: return String(localized: "“\(name)” is with App Review already.", comment: "kind:error")
            case .accepted?, .approved?, .replacedWithNewVersion?:
                return String(localized: "“\(name)” is approved. Suggest newVersion first; submit once the new version’s changes are pushed.", comment: "kind:error")
            }
        case .cancelSubmission:
            guard state == .waitingForReview else {
                return String(localized: "“\(name)” isn’t Waiting for Review, so there’s no submission to cancel.", comment: "kind:error")
            }
            return canCancel ? nil : String(localized: "App Store Connect can’t take this submission back through the API.", comment: "kind:error")
        case .newVersion:
            guard state?.isApproved == true, page.nextVersion == nil else {
                return String(localized: "Only an approved page with no newer version starts a new version.", comment: "kind:error")
            }
            return nil
        }
    }
}
