//
//  GetStorePageTool.swift
//  Atlas
//

import Foundation

/// `get_store_page`: what `suggest_fields` works on for the Store Page:
/// each language's texts (App Store Connect's with anything queued on top),
/// App Store Connect's own where they differ, the limits, and the open
/// suggestions with their source. Languages the app's project has and the
/// App Store page doesn't are listed too, marked new.
struct GetStorePageTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "get_store_page",
        title: "Get Store Page for suggestions",
        description: """
        Reads an app's Store Page in Atlas for suggestions: the newest editable version, its primary \
        locale, and per locale each field's current text, App Store Connect's text where it differs (`live`), \
        and the suggestions already open for it with their source, so you don't repeat them. `fields` gives each \
        field's limit in characters or bytes (keywords count bytes) and whether it's editable. Pass `version` to \
        check it's the one you mean, and `locales` to read only some. `languagesNotOnAppStore` lists the \
        languages the app's project supports and its App Store page doesn't have yet (reported with \
        report_app_support): suggested ones are in `locales` with `new: true` and no texts, so suggest every \
        field for them in that language; added ones (`new: true`, created when the person pushes) too. Their \
        pages are created only when the person adds them. `storeTextRules` lists App Review's rules to follow in \
        every text, and a locale's `states` the fields whose text already breaks one: suggest a version that doesn't. \
        Each locale with keywords has `keywordAnalysis` as the keyword editor shows it: bytes used, duplicates, \
        words already in the name or subtitle (wasted bytes) and the optimized keywords. `dismissed` lists the \
        suggestions the person dismissed for that locale: don't send them again. Send suggestions with suggest_fields.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "version": MCPToolDefinition.string(
                    "The version string, e.g. 1.4, or a new version queued with propose_app_version. Leave it out for the editable version."
                ),
                "platform": MCPStorePlatform.schema,
                "locales": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "App Store Connect locale codes such as de-DE or ja. Leave it out for every locale.",
                ],
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let draft = try await MCPListingDraft.load(
            app: arguments.string("appId"), version: arguments.optionalString("version"), platform: arguments.optionalString("platform"),
            in: context.workspace
        )
        try SuggestFieldsTool.check(version: arguments.optionalString("version"), against: draft.listing.version.versionString, app: draft.app.name)
        let listing = draft.listing
        let locales = try draft.locales(arguments.optionalStrings("locales"), includingNew: true)
        let store = context.workspace.suggestions
        let open = store?.open(for: draft.app.id, area: .storePage) ?? []
        let dismissed = store.map { store in store.all(for: draft.app.id, area: .storePage).filter(store.isDismissed) } ?? []
        let fields = listing.fields.map { field -> (String, JSONValue) in
            (field.rawValue, ["limit": field.limitJSON, "editable": .bool(listing.canEdit(field))])
        }
        let result: JSONValue = [
            "appId": .string(draft.app.id),
            "app": .string(draft.app.name),
            "version": draft.versionJSON,
            "primaryLocale": .string(listing.primaryLocale.code),
            "fields": .object(Dictionary(uniqueKeysWithValues: fields)),
            "storeTextRules": StoreTextRules.json,
            "locales": .array(locales.map { locale in
                Self.entry(
                    for: locale,
                    in: listing,
                    isNew: draft.isNewLanguage(locale) || draft.isUnpushed(locale),
                    suggestions: open.filter { $0.target.scope == .storePage(locale) },
                    dismissed: dismissed.filter { $0.target.scope == .storePage(locale) }
                )
            }),
            "languagesNotOnAppStore": draft.languagesNotOnAppStoreJSON,
        ]
        return .read(Self.addingKnowledge(to: result, appID: draft.app.id, in: context), target: draft.target)
    }

    /// What's known of the app for the texts, and what Atlas still
    /// wants to know.
    private static func addingKnowledge(to result: JSONValue, appID: StoreApp.ID, in context: MCPToolContext) -> JSONValue {
        guard let center = context.workspace.services.storePage.appSupport, case var .object(json) = result else { return result }
        let knowledge = center.knowledge(for: appID) ?? AppKnowledge()
        if !knowledge.isEmpty { json["appKnowledge"] = knowledge.mcpJSON }
        let due = knowledge.due(now: .now)
        if !due.isEmpty {
            json["appQuestions"] = AppKnowledge.questionsJSON(due)
            json["appQuestionsHow"] = """
            If you can read the app's project, answer these with answer_app_questions: Atlas keeps the answers for \
            every later suggestion and run.
            """
        }
        return .object(json)
    }

    private static func entry(
        for locale: StoreLocale,
        in listing: StoreListing,
        isNew: Bool,
        suggestions: [FieldSuggestion],
        dismissed: [FieldSuggestion]
    ) -> JSONValue {
        var texts: [String: JSONValue] = [:]
        var live: [String: JSONValue] = [:]
        var states: [String: JSONValue] = [:]
        for field in listing.fields {
            let draft = listing.draft(field, in: locale)
            if !draft.local.isEmpty { texts[field.rawValue] = .string(draft.local) }
            if draft.isPending { live[field.rawValue] = .string(draft.remote) }
            let issues = StoreTextGuidelineCheck.issues(in: draft.local, for: field)
            if !issues.isEmpty { states[field.rawValue] = .string(issues.assistantNote) }
        }
        var entry: [String: JSONValue] = ["code": .string(locale.code), "name": .string(locale.name), "texts": .object(texts)]
        if isNew { entry["new"] = true }
        if !live.isEmpty { entry["live"] = .object(live) }
        if !states.isEmpty { entry["states"] = .object(states) }
        if !suggestions.isEmpty { entry["suggestions"] = .array(suggestions.map(\.mcpJSON)) }
        if !dismissed.isEmpty {
            entry["dismissed"] = .array(dismissed.suffix(20).map { ["field": .string($0.target.field), "value": .string($0.value)] })
        }
        if let keywords = keywordAnalysis(for: locale, in: listing) { entry["keywordAnalysis"] = keywords }
        return .object(entry)
    }

    /// The keyword editor's reading of a locale's keywords; nil without any.
    static func keywordAnalysis(for locale: StoreLocale, in listing: StoreListing) -> JSONValue? {
        guard listing.fields.contains(.keywords) else { return nil }
        let keywords = listing.draft(.keywords, in: locale).local
        guard !keywords.isEmpty else { return nil }
        let text = { (field: ListingField) in listing.fields.contains(field) ? listing.draft(field, in: locale).local : "" }
        let analysis = KeywordAnalysis(keywords: keywords, name: text(.name), subtitle: text(.subtitle))
        var json: [String: JSONValue] = [
            "bytes": .int(analysis.byteCount),
            "limit": .int(KeywordAnalysis.limit.maximum),
            "summary": .string(analysis.summary),
        ]
        let duplicates = analysis.tokens.filter { $0.state == .duplicate }.map(\.text)
        let wasted = analysis.tokens.filter { $0.state == .inNameOrSubtitle }.map(\.text)
        if !duplicates.isEmpty { json["duplicates"] = .array(duplicates.map(JSONValue.string)) }
        if !wasted.isEmpty { json["inNameOrSubtitle"] = .array(wasted.map(JSONValue.string)) }
        if analysis.canOptimize {
            json["optimized"] = .string(analysis.optimized)
            json["bytesSaved"] = .int(analysis.bytesSaved)
        }
        return .object(json)
    }
}
