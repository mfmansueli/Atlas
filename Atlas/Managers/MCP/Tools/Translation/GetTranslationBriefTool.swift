//
//  GetTranslationBriefTool.swift
//  Atlas
//

import Foundation

/// `get_translation_brief`: one language's brief (`TranslationBrief`), for
/// the native-speaker agent that writes it and the reader that reviews it.
/// Read-only.
struct GetTranslationBriefTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "get_translation_brief",
        title: "Get one language's translation brief",
        description: """
        Everything one language's agent needs to write it natively, and nothing about the other languages: the \
        source texts (in Settings → Translation's source language, else the primary one), what the language has now, \
        each field's limit (name and subtitle 30 characters, promotional text 170, description and What's New 4000, \
        keywords 100 bytes), which fields are keywords or URLs (copyAsIs), glossary (keep: the app's name and the \
        terms kept as they are; approvedHere: texts the person accepted in this language), tone, market (the \
        language's own variant, such as pt-BR against pt-PT, its formality and typography), keywordRules (what 100 \
        bytes hold in this script), projectStrings (the project's catalog, for the app's own words in this language), \
        interfaceLanguage (write reasons and means in it) and storeTextRules. openSuggestions lists your open \
        suggestions in that language, for the review pass. fields limits it to some fields (captions adds the \
        screenshot captions' steps); run is the begin_translation or begin_suggestions run to send them with.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "locale": MCPToolDefinition.string("The language to write, as an App Store Connect locale code, e.g. pt-BR."),
                "fields": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "Only these fields (e.g. subtitle, keywords, whatsNew, or captions). Leave it out for every field the source has.",
                ],
                "run": MCPToolDefinition.string("The run you send the texts with, from begin_translation or begin_suggestions."),
                "version": MCPToolDefinition.string("The version string, e.g. 1.4, or a new version queued with propose_app_version."),
            ],
            required: ["appId", "locale"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let workspace = context.workspace
        let draft = try await MCPListingDraft.load(app: arguments.string("appId"), version: arguments.optionalString("version"), in: workspace)
        let code = try arguments.string("locale")
        guard let locale = try draft.locales([code]).first else { throw MCPToolError.notFound(draft.unknownLocaleMessage(code)) }
        let listing = draft.listing
        let source = TranslationBrief.sourceLocale(of: listing, setting: workspace.translationSource())
        guard locale != source else {
            throw MCPToolError.invalidArgument(name: "locale", expected: String(localized: "a language other than the source, \(source.code)", comment: "kind:error"))
        }
        let (asked, captions) = try TranslationBrief.fields(named: arguments.optionalStrings("fields"))
        let fields = asked ?? listing.fields.filter { listing.canEdit($0) && !listing.value($0, in: source).isEmpty }
        let glossary = workspace.glossary()
        var brief = TranslationBrief(
            appID: draft.app.id,
            appName: draft.app.name,
            locale: locale,
            source: source,
            fields: fields.map { field in
                TranslationBrief.Field(
                    field: field,
                    source: listing.value(field, in: source),
                    current: listing.contains(locale) ? listing.value(field, in: locale) : ""
                )
            },
            keep: glossary.terms,
            tone: glossary.tone
        )
        brief.isNewPage = draft.isNewLanguage(locale)
        brief.projectStrings = draft.languageSource
        brief.interfaceLanguage = Bundle.main.preferredLocalizations.first ?? "en"
        brief.run = try arguments.optionalString("run")
        brief.includesCaptions = captions
        if let store = workspace.suggestions {
            let scope = SuggestionScope.storePage(locale)
            let mine = SuggestionSource.assistant(client: context.clientName)
            brief.approved = store.all(for: draft.app.id, scope: scope)
                .filter(store.isAccepted)
                .sorted { $0.createdAt > $1.createdAt }
                .map { TranslationBrief.Suggested(id: $0.id, field: $0.target.field, value: $0.value) }
            brief.open = store.open(for: draft.app.id, scope: scope)
                .filter { $0.source == mine }
                .map { TranslationBrief.Suggested(id: $0.id, field: $0.target.field, value: $0.value) }
        }
        return .read(brief.json, target: draft.target(locale: locale.code, field: nil))
    }
}
