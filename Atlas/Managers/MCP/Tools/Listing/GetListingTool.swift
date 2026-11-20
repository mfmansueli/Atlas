//
//  GetListingTool.swift
//  Atlas
//

import Foundation

/// `get_listing`: an app's store texts per locale as the Store Page shows
/// them, each field's limit, the glossary to respect and App Review's
/// rules for store text, with the fields already breaking one. `locales`
/// and `fields` read only some: a whole listing in many languages is
/// large (Alba's was 62k characters, more than MCP clients take inline),
/// mostly its descriptions. Without them it's the whole listing, as the
/// prompts that translate or check every field need it.
struct GetListingTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "get_listing",
        title: "Get store listing",
        description: """
        Reads an app's store listing in Atlas: the newest editable version (else the live one, which is \
        read-only), its primary locale, and each locale's texts with anything waiting in review laid on top. \
        `states` says which fields are missing, over the limit, machine-translated, already proposed or would be \
        rejected by App Review (rewrite those). `storeTextRules` lists App Review's rules to follow in every text. \
        `fields` gives each field's level and limit: name, subtitle and privacyPolicyUrl belong to the app; \
        promotionalText, description, keywords (comma-separated, counted in bytes), whatsNew, supportUrl and \
        marketingUrl belong to the version. `glossary.keepUntranslated` lists terms to leave as they are, and \
        `glossary.tone` the tone to write in. Pass `locales` to read only some, and `fields` to read only some \
        fields (name, subtitle, description, keywords, promotionalText, whatsNew, privacyPolicyUrl, supportUrl, \
        marketingUrl, or urls for the three URLs): a whole listing in many languages is large, mostly its \
        descriptions, so ask for what you need, e.g. fields: ["whatsNew"] for release notes; \
        `fieldsNotInThisVersion` names the ones asked for that this version doesn't have (a first version has no \
        whatsNew). `languagesNotOnAppStore` lists \
        the languages the app's project supports and its App Store page doesn't have yet: suggest their texts \
        with suggest_fields; only the person adds their pages.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "locales": [
                    "type": "array",
                    "items": ["type": "string"],
                    "description": "App Store Connect locale codes such as de-DE or ja. Leave it out for every locale.",
                ],
                "fields": [
                    "type": "array",
                    "items": ["type": "string", "enum": .array((ListingField.mcpNames + [Self.urlsName]).map(JSONValue.string))],
                    "description": "The fields to read, or urls for the three URLs. Leave it out for every field.",
                ],
            ],
            required: ["appId"]
        )
    )

    /// "urls" in `fields`: the privacy policy, support and marketing URLs.
    static let urlsName = "urls"

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let draft = try await MCPListingDraft.load(app: arguments.string("appId"), in: context.workspace)
        let listing = draft.listing
        let locales = try draft.locales(arguments.optionalStrings("locales"))
        let requested = try Self.fields(arguments.optionalStrings("fields"))
        let shown = requested.map { wanted in listing.fields.filter(wanted.contains) } ?? listing.fields
        let glossary = context.workspace.glossary()
        let fields = shown.map { field -> (String, JSONValue) in
            let info: JSONValue = [
                "level": .string(field.level == .app ? "app" : "version"),
                "limit": field.limitJSON,
                "editable": .bool(listing.canEdit(field)),
            ]
            return (field.rawValue, info)
        }
        var result: [String: JSONValue] = [
            "appId": .string(draft.app.id),
            "app": .string(draft.app.name),
            "version": draft.versionJSON,
            "primaryLocale": .string(listing.primaryLocale.code),
            "fields": .object(Dictionary(uniqueKeysWithValues: fields)),
            "glossary": [
                "keepUntranslated": .array(glossary.terms.map(JSONValue.string)),
                "tone": .string(glossary.tone.rawValue),
            ],
            "storeTextRules": StoreTextRules.json,
            "locales": .array(locales.map {
                Self.entry(for: $0, in: listing, fields: shown, isNew: draft.isNewLanguage($0) || draft.isUnpushed($0))
            }),
            "languagesNotOnAppStore": draft.languagesNotOnAppStoreJSON,
        ]
        let unavailable = ListingField.allCases.filter { requested?.contains($0) == true && !shown.contains($0) }
        if !unavailable.isEmpty {
            result["fieldsNotInThisVersion"] = .array(unavailable.map { .string($0.rawValue) })
        }
        return .read(.object(result), target: draft.target)
    }

    /// The fields `names` asks for; nil (every field) when none is named.
    /// "urls" stands for the three URLs. An unknown name throws, listing
    /// the known ones.
    static func fields(_ names: [String]?) throws -> Set<ListingField>? {
        guard let names, !names.isEmpty else { return nil }
        var wanted: Set<ListingField> = []
        for name in names {
            if name.caseInsensitiveCompare(urlsName) == .orderedSame {
                wanted.formUnion(ListingField.allCases.filter(\.isURL))
            } else if let field = ListingField.matching(name) {
                wanted.insert(field)
            } else {
                throw MCPToolError.invalidArgument(
                    name: "fields", expected: String(localized: "some of \((ListingField.mcpNames + [urlsName]).joined(separator: ", "))")
                )
            }
        }
        return wanted
    }

    private static func entry(for locale: StoreLocale, in listing: StoreListing, fields: [ListingField], isNew: Bool) -> JSONValue {
        var texts: [String: JSONValue] = [:]
        var states: [String: JSONValue] = [:]
        for field in fields {
            let value = listing.value(field, in: locale)
            if !value.isEmpty { texts[field.rawValue] = .string(value) }
            let issues = StoreTextGuidelineCheck.issues(in: value, for: field)
            let notes = [listing.coverageState(of: field, in: locale).assistantNote, issues.isEmpty ? nil : issues.assistantNote]
                .compactMap(\.self)
            if !notes.isEmpty { states[field.rawValue] = .string(notes.joined(separator: "; ")) }
        }
        var entry: [String: JSONValue] = ["code": .string(locale.code), "name": .string(locale.name), "texts": .object(texts)]
        if isNew { entry["new"] = true }
        if !states.isEmpty { entry["states"] = .object(states) }
        return .object(entry)
    }
}
