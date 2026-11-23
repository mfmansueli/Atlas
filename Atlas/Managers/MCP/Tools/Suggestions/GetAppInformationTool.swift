//
//  GetAppInformationTool.swift
//  Atlas
//

import Foundation

/// `get_app_information`: what `suggest_fields` works on for App
/// Information: General's copyright, categories (and Games
/// subcategories), content rights and release, Age Rating's questions,
/// Accessibility's features per device and its URL, App Privacy's User
/// Privacy Choices URL per language, and App Review's contact, sign-in
/// (never the password) and notes, with App Store Connect's values where
/// they differ, the choices of picked fields and answers, and the open
/// suggestions.
struct GetAppInformationTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "get_app_information",
        title: "Get App Information for suggestions",
        description: """
        Reads an app's App Information in Atlas for suggestions, for the newest editable version (else \
        the live one): page general (copyright, primaryCategory, secondaryCategory, gamesSubcategories, contentRights, \
        release), page ageRating (one entry per question, with its answers), page accessibility (per device, one entry \
        per feature with Apple's meaning, answered Yes or No, and the app's accessibilityUrl in `url`), page appPrivacy \
        (the User Privacy Choices URL, privacyChoicesUrl, per language in `locales`) and page review (contactFirstName, \
        contactLastName, contactPhone, contactEmail, demoAccountRequired, demoAccountName, notes). Each field has its current \
        value, App Store Connect's (`live`) where it differs, \
        its limit, and whether it's locked (the version is in review or live); an unanswered question or \
        feature has value null. Categories, gamesSubcategories, contentRights and release are picked from `choices`, by \
        id. gamesSubcategories (up to two, comma-separated, e.g. "GAMES_PUZZLE,GAMES_WORD"; "" clears them) can be \
        suggested only while the primary category is GAMES (`available`). demoAccountRequired is App Review's \
        "Sign-in required", yes or no; demoAccountName is the demo account's user name. The demo account's \
        password is never read or suggested: the person types it in Atlas. accessibilityUrl is one for the whole \
        app (every device), and privacyChoicesUrl is set per language: suggest it with page appPrivacy and that \
        locale. Both are optional full https:// URLs. \
        contentRights is Apple's "\(ContentRights.appleQuestion)" (its `question`), for the whole app: \
        third-party content is anything the developer doesn't own, such as fonts, images, sounds or music \
        bundled under a license, or content from other services or other people that the app shows or \
        reaches. Suggest USES_THIRD_PARTY_CONTENT (Apple's "Yes, … and I have the necessary rights") when \
        the project has any and it's licensed or permitted, saying in the reason what it is; the person then \
        confirms the rights in Atlas (`rightsConfirmed`). Suggest DOES_NOT_USE_THIRD_PARTY_CONTENT only when \
        everything the app shows is the developer's own. `suggestions` lists \
        the ones already open with their source. App Store Connect won't create review details without a \
        contact email: when the review contact is empty, suggest it from what the project shows (a support or \
        contact email in the app or its docs, or the git author's name and email), and never make up a phone \
        number. Send suggestions with suggest_fields. Pass `version` with a new version queued with \
        propose_app_version to read it before it's in App Store Connect: its copyright, release and App Review \
        fields start from the version before it and aren't locked, and what suggest_fields sends for them with the \
        same `version` waits with it in Review & Push, as do its categories, Games subcategories and User Privacy \
        Choices URLs (App Store Connect makes a new app info with the version). contentRights and accessibilityUrl \
        belong to the app, not to a version: they're never locked, and with `version` they're suggested for the app \
        as without, not queued with the new version.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "version": MCPToolDefinition.string(
                    "A version, e.g. 1.2: the one being prepared (when left out), or a new one queued with propose_app_version."
                ),
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let draft = try await MCPAppInformationDraft.load(
            app: arguments.string("appId"), version: arguments.optionalString("version"), in: context.workspace, includesPrivacyURLs: true
        )
        let open = context.workspace.suggestions?.open(for: draft.app.id, area: .appInformation) ?? []
        let pages = AppInformationSuggestionField.pages.map { page -> JSONValue in
            let fields = AppInformationSuggestionField.fields(on: page).map { field in (field.rawValue, Self.entry(for: field, in: draft)) }
            return [
                "page": .string(SuggestFieldsTool.mcpPageName(page.rawValue)),
                "fields": .object(Dictionary(uniqueKeysWithValues: fields)),
            ]
        }
        let result: JSONValue = [
            "appId": .string(draft.app.id),
            "app": .string(draft.app.name),
            "version": draft.versionJSON,
            "pages": .array(pages + [Self.ageRating(in: draft), Self.accessibility(in: draft), Self.appPrivacy(in: draft)]),
            "choices": [
                "categories": .array(AppCategory.all.map { ["id": .string($0.id), "name": .string($0.name)] }),
                "gamesSubcategories": .array(AppCategory.gamesSubcategories.map { ["id": .string($0.id), "name": .string($0.name)] }),
                "release": .array(ReleaseOption.allCases.map { ["id": .string($0.rawValue), "name": .string($0.title)] }),
                "contentRights": .array(ContentRights.allCases.map(\.mcpChoice)),
            ],
            "suggestions": .array(open.map(\.mcpJSON)),
        ]
        return .read(result, target: draft.target(nil))
    }

    private static func entry(for field: AppInformationSuggestionField, in draft: MCPAppInformationDraft) -> JSONValue {
        let value = draft.value(field)
        var entry: [String: JSONValue] = [
            "value": .string(value),
            "locked": .bool(draft.isLocked(field)),
            "limit": field.limit.map { ["max": .int($0), "unit": "characters"] } ?? .null,
        ]
        if field.isPicked, !value.isEmpty { entry["name"] = .string(field.displayValue(value)) }
        if field == .gamesSubcategories {
            entry["available"] = .bool(draft.slots.canSuggest(.field(field)))
            entry["max"] = 2
        }
        let live = draft.liveValue(field)
        if live != value { entry["live"] = .string(live) }
        if field == .contentRights {
            entry["question"] = .string(ContentRights.appleQuestion)
            if value == ContentRights.usesThirdPartyContent.rawValue { entry["rightsConfirmed"] = .bool(draft.general.rightsConfirmed) }
        }
        return .object(entry)
    }

    /// Every question, or `available: false` before App Store Connect has a
    /// questionnaire for the app.
    private static func ageRating(in draft: MCPAppInformationDraft) -> JSONValue {
        let questions = AgeRatingQuestion.allCases.map { question in
            var entry = answerEntry(.ageRating(question), in: draft)
            entry["title"] = .string(question.title)
            return (question.rawValue, JSONValue.object(entry))
        }
        return [
            "page": .string(AppInformationPage.ageRating.rawValue),
            "available": .bool(draft.slots.canSuggest(.ageRating(.wellness))),
            "questions": .object(Dictionary(uniqueKeysWithValues: questions)),
        ]
    }

    /// One entry per device the app runs on, with the features asked there.
    private static func accessibility(in draft: MCPAppInformationDraft) -> JSONValue {
        let devices = draft.slots.accessibilityFamilies.map { family -> JSONValue in
            let features = family.features.map { feature in
                var entry = answerEntry(.accessibility(family, feature), in: draft)
                entry["name"] = .string(feature.name)
                entry["meaning"] = .string(feature.meaning)
                return (feature.rawValue, JSONValue.object(entry))
            }
            return [
                "device": .string(family.mcpName),
                "name": .string(family.name),
                "declared": .bool(draft.slots.card(for: family)?.shown != nil),
                "features": .object(Dictionary(uniqueKeysWithValues: features)),
            ]
        }
        return [
            "page": .string(AppInformationPage.accessibility.rawValue),
            "available": .bool(draft.slots.accessibility != nil),
            "devices": .array(devices),
            "url": draft.slots.accessibility == nil ? .null : .object(urlEntry(.field(.accessibilityURL), in: draft)),
        ]
    }

    /// The User Privacy Choices URL in each language App Privacy has, or
    /// `available: false` when the URLs couldn't be read.
    private static func appPrivacy(in draft: MCPAppInformationDraft) -> JSONValue {
        let locales = draft.slots.privacyLocales.map { locale -> JSONValue in
            [
                "locale": .string(locale.code),
                "name": .string(locale.name),
                "fields": [AppInformationSuggestionSlot.privacyChoicesField: .object(urlEntry(.privacyChoicesURL(locale), in: draft))],
            ]
        }
        return [
            "page": .string(AppInformationPage.appPrivacy.rawValue),
            "available": .bool(draft.slots.privacyURLs != nil),
            "locales": .array(locales),
        ]
    }

    /// A URL's `value` ("" when there's none) and `live` where it differs.
    private static func urlEntry(_ slot: AppInformationSuggestionSlot, in draft: MCPAppInformationDraft) -> [String: JSONValue] {
        let value = draft.slots.value(slot)
        var entry: [String: JSONValue] = ["value": .string(value), "locked": false]
        let live = draft.slots.liveValue(slot)
        if live != value { entry["live"] = .string(live) }
        return entry
    }

    /// `value` and `live` by name ("Yes", "Infrequent"; null when
    /// unanswered) and the answers it takes.
    private static func answerEntry(_ slot: AppInformationSuggestionSlot, in draft: MCPAppInformationDraft) -> [String: JSONValue] {
        func name(_ value: String) -> JSONValue { value.isEmpty ? .null : .string(slot.displayValue(value)) }
        let value = draft.slots.value(slot)
        var entry: [String: JSONValue] = [
            "value": name(value),
            "answers": .array(slot.choices.map { .string(slot.displayValue($0)) }),
        ]
        let live = draft.slots.liveValue(slot)
        if live != value { entry["live"] = name(live) }
        return entry
    }
}
