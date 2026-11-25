//
//  TranslationBrief.swift
//  Atlas
//

import Foundation

/// What one language's agent needs to write that language natively, and
/// nothing about the others: `get_translation_brief`'s answer. The source
/// texts beside what the language has now, each field's limit and rules,
/// the words to keep, the words already approved in this language, tone,
/// market notes and App Review's rules. The reviewer reads the same brief
/// with the suggestions it reviews (`open`).
struct TranslationBrief {
    /// One field to write.
    struct Field: Hashable, Sendable {
        var field: ListingField
        /// In the source language.
        var source: String
        /// What the language has now: App Store Connect's text with what's
        /// queued laid on top.
        var current: String
    }

    /// A suggestion already in this language, by id: the person's accepted
    /// ones (approved words) or the assistant's open ones (to review).
    struct Suggested: Hashable, Sendable {
        var id: String
        var field: String
        var value: String
    }

    var appID: String
    var appName: String
    var locale: StoreLocale
    var source: StoreLocale
    var fields: [Field]
    /// Settings → Translation's terms to keep.
    var keep: [String]
    var tone: TranslationTone
    /// Values the person accepted in this language, newest first.
    var approved: [Suggested] = []
    /// The assistant's open suggestions in this language, for the review.
    var open: [Suggested] = []
    /// The project has the language and the App Store page doesn't yet.
    var isNewPage = false
    /// The project's catalog, e.g. "Localizable.xcstrings".
    var projectStrings: String?
    /// The language Atlas's interface is in: `means` and reasons are
    /// written in it.
    var interfaceLanguage = "en"
    /// The run the texts are sent with.
    var run: String?
    /// Whether the agent also writes this language's screenshot captions.
    var includesCaptions = false

    /// How many approved values the brief carries at most.
    static let approvedLimit = 12

    /// The field `fields` names for screenshot captions.
    static let captionsField = "captions"

    /// What translations start from: Settings → Translation's language
    /// when the page has it, else the primary one.
    static func sourceLocale(of listing: StoreListing, setting: String?) -> StoreLocale {
        guard let setting, let locale = StoreLocaleCatalog.locale(code: setting), listing.contains(locale) else { return listing.primaryLocale }
        return locale
    }

    /// The Store Page fields `names` lists, and whether it asks for
    /// captions; nil fields when it names none.
    static func fields(named names: [String]?) throws -> (fields: [ListingField]?, captions: Bool) {
        guard let names else { return (nil, false) }
        let captions = names.contains { $0.caseInsensitiveCompare(captionsField) == .orderedSame }
        let fields = try names.filter { $0.caseInsensitiveCompare(captionsField) != .orderedSame }.map { name in
            guard let field = ListingField.matching(name) else {
                throw MCPToolError.invalidArgument(name: "fields", expected: (ListingField.mcpNames + [captionsField]).joined(separator: ", "))
            }
            return field
        }
        var unique: [ListingField] = []
        for field in fields where !unique.contains(field) {
            unique.append(field)
        }
        return (unique, captions)
    }

    /// The app's name first, then the glossary's terms, each once.
    var keepTerms: [String] {
        var terms: [String] = []
        for term in [appName] + keep where !terms.contains(where: { $0.caseInsensitiveCompare(term) == .orderedSame }) {
            terms.append(term)
        }
        return terms
    }

    var json: JSONValue {
        var result: [String: JSONValue] = [
            "appId": .string(appID),
            "app": .string(appName),
            "locale": Self.localeJSON(locale),
            "sourceLocale": Self.localeJSON(source),
            "interfaceLanguage": .string(interfaceLanguage),
            "tone": .string(tone.promptPhrase),
            "market": .string(TranslationMarketNotes.note(for: locale)),
            "keywordRules": .string(TranslationMarketNotes.keywordRules(for: locale)),
            "fields": .array(fields.map(fieldJSON)),
            "glossary": [
                "keep": .array(keepTerms.map(JSONValue.string)),
                "approvedHere": .array(approved.prefix(Self.approvedLimit).map(Self.json)),
            ],
            "storeTextRules": StoreTextRules.json,
            "write": .string(writeNote),
        ]
        if !open.isEmpty { result["openSuggestions"] = .array(open.map(Self.json)) }
        if isNewPage {
            result["newPage"] = .string("""
            \(locale.name) isn't on the App Store yet: your suggestions show in its own tab of the Store Page, and its page \
            is created only when the person adds it.
            """)
        }
        if let projectStrings {
            result["projectStrings"] = .string("""
            \(projectStrings): read its \(locale.code) entries (or \(locale.languageCode)) for the words the app's own \
            interface uses in \(locale.name), and use the same ones.
            """)
        }
        if let run { result["run"] = .string(run) }
        if includesCaptions {
            result["captions"] = .string("""
            Write this language's screenshot captions too: read get_captions for \(locale.code), see each screen with \
            get_capture, check each caption with measure_caption until it fits at full size, and send them in one \
            propose_captions call for \(locale.code).
            """)
        }
        return .object(result)
    }

    /// How to write, in one paragraph.
    private var writeNote: String {
        """
        Write as a native \(locale.name) copywriter writing \(appName)'s page from scratch for this market: the same \
        message and facts as the \(source.name) source, in natural \(locale.name) phrasing, never word for word. Keep \
        the terms in glossary.keep exactly as they are, and reuse the words in glossary.approvedHere. Keep the tone \
        \(tone.promptPhrase).
        """
    }

    private func fieldJSON(_ entry: Field) -> JSONValue {
        let field = entry.field
        var json: [String: JSONValue] = [
            "field": .string(field.rawValue),
            "kind": .string(field == .keywords ? "keywords" : field.isURL ? "url" : "text"),
            "source": .string(entry.source),
            "current": .string(entry.current),
            "missing": .bool(entry.current.isEmpty),
            "limit": field.limitJSON,
        ]
        if field.isURL { json["copyAsIs"] = true }
        if let note = note(for: field) { json["note"] = .string(note) }
        return .object(json)
    }

    /// What a field asks for beyond its limit.
    private func note(for field: ListingField) -> String? {
        switch field {
        case .name: "Keep the brand (\(appName)) as it is; the words after it may be in \(locale.name). At most 30 characters."
        case .subtitle: "What the app does, in words people search for, without repeating the name's words. At most 30 characters."
        case .promotionalText: "Above the description, changes without App Review: a current reason to download. At most 170 characters."
        case .description: "The first three lines show before “more”: lead with the benefit. Keep the source's paragraphs and lists."
        case .keywords: TranslationMarketNotes.keywordRules(for: locale)
        case .whatsNew: "What people get in this version, in short lines. Describe only what this version does."
        case .privacyPolicyURL, .supportURL, .marketingURL: "A URL: copy it as it is, unless the source has a page in this language."
        }
    }

    private static func localeJSON(_ locale: StoreLocale) -> JSONValue {
        var json: [String: JSONValue] = ["code": .string(locale.code), "name": .string(locale.name)]
        if locale.isRTL { json["rightToLeft"] = true }
        return .object(json)
    }

    private static func json(_ suggested: Suggested) -> JSONValue {
        ["id": .string(suggested.id), "field": .string(suggested.field), "value": .string(suggested.value)]
    }
}
