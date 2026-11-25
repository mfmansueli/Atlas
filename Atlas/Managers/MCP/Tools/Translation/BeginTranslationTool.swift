//
//  BeginTranslationTool.swift
//  Atlas
//

import Foundation

/// `begin_translation`: texts in several languages, one native-speaker
/// agent per language. Atlas plans each language's fields (leaving out the
/// ones `begin_suggestions` would), starts a `.translation` run counted by
/// language ("Translating · 4 of 12 languages"), and hands back each
/// language's writer and reviewer prompts for the coordinating assistant to
/// give its agents as they are.
struct BeginTranslationTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "begin_translation",
        title: "Begin translating into several languages",
        description: """
        Starts writing an app's Store Page in several languages, one native-speaker agent per language, and you \
        coordinate. Pass locales (App Store Connect codes) and, when only some are asked, fields (name, subtitle, \
        promotionalText, description, keywords, whatsNew, the URLs, or captions for the screenshot captions); \
        without fields, each language gets the fields that are empty there while the source language has text, and \
        with fields and missingOnly true, only those of them that are empty. \
        Returns run, which Atlas counts by language; maxAgents, how many agents to run at once; and per language \
        its fields, the ones skipped with a code (as begin_suggestions: changed_by_you, locked, in_another_request, \
        already_suggested, unknown_locale…), writer and reviewer: the prompts to give that language's two agents, \
        exactly as they are. Start the writers with the Agent tool, at most maxAgents at a time; when a writer is \
        done, start its reviewer. Each agent reads its language with get_translation_brief and sends it with \
        suggest_fields and the run, so it shows in Atlas as soon as it's done; the reviewer ends its language with \
        end_suggestions and the locale. Call end_suggestions with the run when every language is done. Refused while \
        another run goes on: send the languages with that run instead.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "locales": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "The languages to write, as App Store Connect locale codes, e.g. [\"de-DE\", \"pt-BR\", \"ja\"].",
                ],
                "fields": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Only these fields in each language (or captions). Leave it out for every empty field.",
                ],
                "missingOnly": ["type": "boolean", "description": "With fields: only the ones empty in each language."],
                "version": MCPToolDefinition.string("The version string, e.g. 1.4, to check it's the one being prepared."),
            ],
            required: ["appId", "locales"]
        )
    )

    /// One language's share of the run.
    private struct Language {
        var locale: StoreLocale
        var fields: [String] = []
        var skipped: [JSONValue] = []
    }

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        guard let store = context.workspace.suggestions else {
            throw MCPToolError.unavailable(String(localized: "Suggestions aren’t available right now. Ask the person to open Atlas."))
        }
        if let going = store.run, going.isRunning {
            throw MCPToolError.unavailable(String(
                localized: "Run “\(going.id)” is still going. Send these languages with it, or end it with end_suggestions first.",
                comment: "kind:error"
            ))
        }
        let locales = try Self.locales(arguments.optionalStrings("locales"))
        let (asked, captions) = try TranslationBrief.fields(named: arguments.optionalStrings("fields"))
        let missingOnly = try arguments.optionalBool("missingOnly") ?? false
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let candidates = asked ?? ListingField.allCases
        let items = try locales.flatMap { locale in try candidates.map { try Self.item(locale, $0) } }
        let session = try await MCPSuggestionSession(app: app, items: items, store: store, context: context, applies: false)
        try session.check(version: arguments.optionalString("version"))
        let listing = session.listing?.listing
        let source = listing.map { TranslationBrief.sourceLocale(of: $0, setting: context.workspace.translationSource()) }

        let mine = SuggestionSource.assistant(client: context.clientName)
        var plan: [SuggestionTarget] = []
        var languages: [Language] = []
        var nothingToDo: [JSONValue] = []
        for locale in locales {
            var language = Language(locale: locale)
            if locale == source {
                nothingToDo.append(["locale": .string(locale.code), "reason": "It's the source language."])
                continue
            }
            let missing = listing.map { Self.missing(in: locale, of: $0, source: source ?? $0.primaryLocale) } ?? []
            let fields = asked.map { asked in missingOnly ? asked.filter(missing.contains) : asked } ?? missing
            for field in fields {
                let item = try Self.item(locale, field)
                switch session.planned(item).flatMap({ BeginSuggestionsTool.leftToOthers($0, store: store, appID: app.id, source: mine) }) {
                case let .success(target):
                    plan.append(target)
                    language.fields.append(field.rawValue)
                case let .failure(skip):
                    language.skipped.append(["field": .string(field.rawValue), "code": .string(skip.code), "reason": .string(skip.reason)])
                }
            }
            guard !language.fields.isEmpty || captions else {
                nothingToDo.append([
                    "locale": .string(locale.code),
                    "reason": language.skipped.isEmpty ? "Nothing in it is missing." : "Every field was skipped.",
                    "skipped": .array(language.skipped),
                ])
                continue
            }
            languages.append(language)
        }
        guard !languages.isEmpty else {
            let result: JSONValue = ["run": .null, "languages": [], "nothingToDo": .array(nothingToDo)]
            return .read(result, target: String(localized: "\(app.name) · nothing to translate", comment: "kind:other"))
        }
        let run = store.startRun(appID: app.id, client: context.clientName, plan: plan, kind: .translation, languages: languages.map(\.locale.code))
        let result: JSONValue = [
            "run": .string(run.id),
            "maxAgents": .int(NativeTranslationFlow.maxAgents),
            "sourceLocale": source.map { JSONValue.string($0.code) } ?? .null,
            "accepted": .int(run.plan.count),
            "languages": .array(languages.map { Self.json($0, app: app, run: run.id, captions: captions) }),
            "nothingToDo": .array(nothingToDo),
        ]
        return .read(result, target: String(localized: "\(app.name) · \(languages.count) languages", comment: "kind:other"))
    }

    // MARK: - Helpers

    /// The codes asked for, each a known App Store locale, once.
    private static func locales(_ codes: [String]?) throws -> [StoreLocale] {
        let expected = String(localized: "App Store Connect locale codes, e.g. [\"de-DE\", \"ja\"]")
        guard let codes, !codes.isEmpty else { throw MCPToolError.invalidArgument(name: "locales", expected: expected) }
        var locales: [StoreLocale] = []
        for code in codes {
            guard let locale = StoreLocaleCatalog.locale(code: code) else { throw MCPToolError.invalidArgument(name: "locales", expected: expected) }
            if !locales.contains(locale) { locales.append(locale) }
        }
        return locales
    }

    /// A plan entry for one field in one language.
    private static func item(_ locale: StoreLocale, _ field: ListingField) throws -> MCPSuggestionItem {
        try MCPSuggestionItem(["area": "store", "locale": .string(locale.code), "field": .string(field.rawValue)], isPlanned: true)
    }

    /// The fields empty in `locale` while the source has text, as
    /// `list_missing_translations` lists them.
    static func missing(in locale: StoreLocale, of listing: StoreListing, source: StoreLocale) -> [ListingField] {
        listing.fields.filter { field in
            let current = listing.contains(locale) ? listing.value(field, in: locale) : ""
            return listing.canEdit(field) && current.isEmpty && !listing.value(field, in: source).isEmpty
        }
    }

    /// `{locale, name, fields, captions, skipped, writer, reviewer}`.
    private static func json(_ language: Language, app: StoreApp, run: String, captions: Bool) -> JSONValue {
        let hasReviewer = !language.fields.isEmpty
        var json: [String: JSONValue] = [
            "locale": .string(language.locale.code),
            "name": .string(language.locale.name),
            "fields": .array(language.fields.map(JSONValue.string)),
            "captions": .bool(captions),
            "skipped": .array(language.skipped),
            "writer": .string(TranslationAgentPrompt.writer(
                app: app.name, appID: app.id, locale: language.locale, fields: language.fields, captions: captions, run: run
            )),
        ]
        if hasReviewer {
            json["reviewer"] = .string(TranslationAgentPrompt.reviewer(app: app.name, appID: app.id, locale: language.locale, run: run))
        }
        return .object(json)
    }
}
