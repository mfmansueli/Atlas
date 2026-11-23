//
//  SuggestFieldsTool.swift
//  Atlas
//

import Foundation

/// `suggest_fields`: an assistant's suggested values for Store Page and App
/// Information fields. Each item is checked like an edit (the field, the
/// limit, a locked version, the person's permissions) and shows under its
/// field for the person to accept, edit or dismiss. Nothing changes until
/// they do, unless they chose "Suggest and edit drafts" and the call says
/// `apply`: then the value is queued as an unpushed change marked with the
/// assistant.
struct SuggestFieldsTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "suggest_fields",
        title: "Suggest field values",
        description: """
        Suggests values for an app's fields in Atlas; each one shows under its field until the person \
        accepts, edits or dismisses it. Items are {area, locale | page, device, field, value, reason, evidence}: \
        area store with a locale code and a Store Page field (\(ListingField.mcpNames.joined(separator: ", "))), \
        or area info with page general (copyright, primaryCategory, secondaryCategory, gamesSubcategories, \
        secondaryGamesSubcategories, contentRights, release; contentRights is USES_THIRD_PARTY_CONTENT or \
        DOES_NOT_USE_THIRD_PARTY_CONTENT, or yes or no; gamesSubcategories is up to two Games subcategory ids, \
        comma-separated, only while the primary category is GAMES, and secondaryGamesSubcategories the same while the \
        secondary category is GAMES), page review (contactFirstName, contactLastName, contactPhone, contactEmail, \
        demoAccountRequired yes or no, demoAccountName, notes; the demo account's password is never suggested), \
        page ageRating (field is a question, value one of its answers), page accessibility with a device (iphone, \
        ipad, watch, vision, mac, tv; field is a feature, value yes or no) or field accessibilityUrl (the app's, no \
        device), or page appPrivacy with a locale and field privacyChoicesUrl (the User Privacy Choices URL in that \
        language). Give a one-sentence reason and \
        evidence such as {kind: "git", ref: "v1.3..4f2c91a"} or {kind: "code", ref: "File.swift:18"}. Per item, \
        status is queued, unchanged (the field already has that value or you suggested it already), updated (you \
        suggested that value already and it took your new reason or evidence, same id), replaced (your older open \
        suggestion for the field was replaced: send a field again to change your value or its reason) or refused \
        with a code: over_limit (with count), \
        unknown_field, unknown_locale, locked (the version is in review), not_permitted, invalid_value or \
        invalid_answer (not one of the question's or feature's answers), guideline (store text App Review would \
        reject, with issues [{kind, guideline, phrases}]: pricing such as “free”, prices, discounts or trials, other \
        platforms, other apps' names, unverifiable claims, beta or demo, placeholders, “coming soon” or “For Kids”; \
        rewrite it as the reason says) or run_stopped (the person stopped receiving the run: stop sending). Follow \
        get_store_page's storeTextRules. Pass total, how many you'll send in all, so Atlas shows \
        progress; when suggesting everything, call begin_suggestions with your plan first and pass its run \
        instead. apply: true queues the values as changes instead, only when the person allowed editing \
        drafts. A store locale may also be a language the app supports and the App Store doesn't have yet \
        (get_store_page's languagesNotOnAppStore): it stays a suggestion, even with apply, in its own tab \
        until the person adds the page. Read get_store_page and get_app_information first. Take back your own open \
        suggestions that went stale (a reason that cites a date that moved, a value no longer right) with \
        withdraw_suggestion and their ids. version may also be a new version queued with propose_app_version: its \
        fields (whatsNew, description, keywords, promotionalText, URLs, copyright, release, page review, and \
        name, subtitle, privacy URLs (privacyChoicesUrl too), categories, both Games subcategories and age rating, which \
        go into the app info App Store Connect makes with it) are then queued with it in Review & Push (status \
        applied, with a note) instead of shown as suggestions, since it has no page in Atlas yet; they go into it \
        right after Atlas creates it, and are discarded with it. contentRights and accessibilityUrl belong to the \
        app, so with version they're handled as without.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "version": MCPToolDefinition.string(
                    "The version string, e.g. 1.4: the one being prepared, or a new version queued with propose_app_version."
                ),
                "items": ["type": "array", "description": "The suggestions, one per field.", "items": Self.itemSchema],
                "total": ["type": "integer", "description": "How many suggestions you'll send in all, across calls."],
                "run": MCPToolDefinition.string("The run begin_suggestions returned, when suggesting everything."),
                "apply": ["type": "boolean", "description": "Queue the values as changes. Only with “Suggest and edit drafts”."],
            ],
            required: ["appId", "items"]
        )
    )

    private static let itemSchema = MCPToolDefinition.schema(
        [
            "area": MCPToolDefinition.string("store or info."),
            "locale": MCPToolDefinition.string("For store and for appPrivacy: an App Store Connect locale code, e.g. en-US."),
            "page": MCPToolDefinition.string("For info: general, ageRating, accessibility, appPrivacy or review."),
            "device": MCPToolDefinition.string("For accessibility: iphone, ipad, watch, vision, mac or tv."),
            "field": MCPToolDefinition.string("The field, question or feature, e.g. whatsNew, notes, wellness or voiceOver."),
            "value": MCPToolDefinition.string(
                """
                The suggested value, within the field's limit. Categories, Games subcategories, contentRights and release by id; \
                an answer by name, e.g. Yes or Infrequent.
                """
            ),
            "reason": MCPToolDefinition.string("One sentence: why this value."),
            "evidence": ["type": "array", "items": evidenceSchema],
        ],
        required: ["field", "value"]
    )

    private static let evidenceSchema = MCPToolDefinition.schema(
        ["kind": MCPToolDefinition.string("git, code, review, …"), "ref": MCPToolDefinition.string("What to look at.")],
        required: ["kind", "ref"]
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        guard let store = context.workspace.suggestions else {
            throw MCPToolError.unavailable(String(localized: "Suggestions aren’t available right now. Ask the person to open Atlas."))
        }
        let items = try arguments.array("items").map { item in
            guard let object = item.objectValue else {
                throw MCPToolError.invalidArgument(name: "items", expected: String(localized: "a list of {area, locale | page, field, value, reason} objects"))
            }
            return try MCPSuggestionItem(object)
        }
        let wantsApply = try arguments.optionalBool("apply") ?? false
        let runID = try arguments.optionalString("run")
        if let runID, store.isStopped(runID) { return Self.stopped(items) }
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        var session = try await MCPSuggestionSession(
            app: app,
            items: items,
            store: store,
            context: context,
            applies: wantsApply && context.editsDrafts,
            runID: runID,
            version: arguments.optionalString("version")
        )
        try session.check(version: arguments.optionalString("version"))
        if let total = try arguments.optionalInt("total") {
            store.noteExpectedTotal(total, client: context.clientName, appID: app.id)
        }

        var results: [JSONValue] = []
        var logLines: [MCPToolOutcome.LogLine] = []
        for item in items {
            var settled = session.suggest(item)
            if wantsApply, !session.applies, settled.result["status"] != "refused" {
                settled.result["note"] = "apply needs “Suggest and edit drafts” in Atlas; it's waiting as a suggestion instead."
            }
            results.append(.object(settled.result))
            logLines.append(settled.logLine)
        }
        session.commit()
        let summary: JSONValue = [
            "results": .array(results),
            "queued": .int(results.count { ["queued", "replaced", "updated", "applied"].contains($0["status"]?.stringValue) }),
            "refused": .int(results.count { $0["status"]?.stringValue == "refused" }),
        ]
        return MCPToolOutcome(result: summary, isError: false, logLines: logLines)
    }

    // MARK: - Helpers

    /// Every item refused: the person pressed Stop Receiving.
    private static func stopped(_ items: [MCPSuggestionItem]) -> MCPToolOutcome {
        let refusal = MCPSuggestionRefusal.runStopped
        let results = items.map { item -> JSONValue in
            var result: [String: JSONValue] = ["field": .string(item.field)]
            result.merge(refusal.json) { _, new in new }
            return .object(result)
        }
        let summary: JSONValue = ["results": .array(results), "queued": 0, "refused": .int(results.count)]
        let line = MCPToolOutcome.LogLine(target: "", outcome: .refused, reason: refusal.reason)
        return MCPToolOutcome(result: summary, isError: false, logLines: [line])
    }

    /// A `version` argument that isn't the one being prepared.
    static func check(version: String?, against shown: String, app: String) throws {
        guard let version, version != shown else { return }
        throw MCPToolError.notFound(String(localized: "\(app)’s version being prepared is \(shown), not \(version). Suggestions are for \(shown)."))
    }

    /// `general`, `ageRating`, `accessibility`, `appPrivacy` or `review`,
    /// as MCP names App Information's pages.
    nonisolated static func mcpPageName(_ page: String) -> String {
        page == AppInformationPage.appReview.rawValue ? "review" : page
    }

    /// The page an assistant named: `general`, `ageRating` (or `age`),
    /// `accessibility`, `appPrivacy` (or `privacy`), `review` or `appReview`.
    nonisolated static func page(named name: String) -> AppInformationPage? {
        switch name.replacingOccurrences(of: "_", with: "").lowercased() {
        case "general": .general
        case "agerating", "age": .ageRating
        case "accessibility": .accessibility
        case "appprivacy", "privacy": .appPrivacy
        case "review", "appreview": .appReview
        default: nil
        }
    }
}
