//
//  ProductPageChangeBuilder+NewPage.swift
//  Atlas
//

import Foundation

// A page made in Atlas: one change that creates it (`POST
// /v1/appCustomProductPages`, with its first version inline and, from the
// default page or another page, that page as its template), then writes
// each language's text and keywords into it (`ProductPageLocaleWrite`, on
// `{createdID:appCustomProductPages}`). Review & Push shows it as
// "Create “Private diary”" with what it's created with under it.
extension ProductPageChangeBuilder {
    static let newSuffix = "new"
    static let createdPage = PushRequest.createdIDPlaceholder(type: pageType)

    func newPageChangeID(draftID: ProductPageDraft.ID) -> String {
        "\(idPrefix)\(draftID).\(Self.newSuffix)"
    }

    func isNewPage(_ change: PendingChange) -> Bool {
        owns(change) && change.id.hasSuffix(".\(Self.newSuffix)")
    }

    func newPageChange(_ draft: ProductPageDraft, defaultPage: ProductPageDefault) -> PendingChange? {
        let document = Self.createDocument(draft, appID: appID, templateVersionID: defaultPage.versionID)
        guard let body = try? JSONSerialization.data(withJSONObject: document, options: [.sortedKeys, .withoutEscapingSlashes]) else { return nil }
        var requests = [PushRequest(method: .post, path: "/v1/\(Self.pageType)", body: body)]
        let inline = Self.inlineLocales(draft)
        for locale in draft.locales {
            let text = draft.promotionalTexts[locale] ?? ""
            let keywords = draft.keywords[locale] ?? []
            // A language made inline already has its text.
            let writesText = !inline.contains(locale) && !text.isEmpty
            guard writesText || !keywords.isEmpty else { continue }
            let write = ProductPageLocaleWrite(.init(
                pageID: Self.createdPage, locale: locale, promotionalText: writesText ? text : nil, addKeywords: keywords
            ))
            requests.append(write.request)
        }
        let id = newPageChangeID(draftID: draft.id)
        let title = String(localized: "Create “\(draft.name)”")
        let keywordCount = draft.keywords.values.reduce(0) { $0 + $1.count }
        var change = PendingChange(
            id: id,
            appID: appID, section: .productPages, group: group(draft.name), groupID: draft.id,
            title: title, oldValue: "",
            newValue: "\(ReviewText.languages(draft.locales.count)) · \(Self.keywordCountText(keywordCount))",
            source: draft.source, blockedReason: Self.problem(of: draft), requests: requests
        )
        change.creation = PendingCreation(
            id: id, title: title,
            detail: String(localized: """
            A new custom product page with a link of its own. It goes to App Review by itself, and it can be made visible \
            once Apple approves it.
            """),
            source: draft.source,
            fields: Self.fields(of: draft, versionString: defaultPage.versionString)
        )
        return change
    }

    /// The page, its first version and, for a page that starts empty, its
    /// languages, made in one request.
    static func createDocument(_ draft: ProductPageDraft, appID: StoreApp.ID, templateVersionID: String?) -> [String: Any] {
        let versionID = "${v1}"
        let inline = inlineLocales(draft)
        let localizationIDs = inline.indices.map { "${l\($0 + 1)}" }
        var relationships: [String: Any] = [
            "app": ["data": ["type": "apps", "id": appID]],
            "appCustomProductPageVersions": ["data": [["type": ProductPageLocaleWrite.versionType, "id": versionID]]],
        ]
        switch draft.start {
        case .defaultPage:
            if let templateVersionID {
                relationships["appStoreVersionTemplate"] = ["data": ["type": "appStoreVersions", "id": templateVersionID]]
            }
        case let .copy(pageID, _):
            relationships["customProductPageTemplate"] = ["data": ["type": pageType, "id": pageID]]
        case .empty:
            break
        }
        var version: [String: Any] = [
            "type": ProductPageLocaleWrite.versionType, "id": versionID,
            "relationships": ["appCustomProductPageLocalizations": ["data": localizationIDs.map {
                ["type": ProductPageLocaleWrite.localizationType, "id": $0]
            }]],
        ]
        let link = draft.deepLink.trimmingCharacters(in: .whitespaces)
        if !link.isEmpty { version["attributes"] = ["deepLink": link] }
        var included: [[String: Any]] = [version]
        for (index, locale) in inline.enumerated() {
            var attributes: [String: Any] = ["locale": locale]
            if let text = draft.promotionalTexts[locale], !text.isEmpty { attributes["promotionalText"] = text }
            included.append([
                "type": ProductPageLocaleWrite.localizationType, "id": localizationIDs[index], "attributes": attributes,
                "relationships": ["appCustomProductPageVersion": ["data": ["type": ProductPageLocaleWrite.versionType, "id": versionID]]],
            ])
        }
        return [
            "data": ["type": pageType, "attributes": ["name": draft.name], "relationships": relationships],
            "included": included,
        ]
    }

    /// The languages made inside the create request: a page from a
    /// template gets its languages from the template, so only an empty one
    /// lists them.
    static func inlineLocales(_ draft: ProductPageDraft) -> [String] {
        draft.start == .empty ? draft.locales : []
    }

    /// What stops a draft from being pushed: no name, or a text over the
    /// limit.
    static func problem(of draft: ProductPageDraft) -> String? {
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return String(localized: "A page needs a name.") }
        for locale in draft.locales {
            if let problem = textProblem(draft.promotionalTexts[locale] ?? "") { return "\(localeName(locale)): \(problem)" }
        }
        return ProductPageDeepLinkCheck(link: draft.deepLink, domains: []).blockingProblem
    }

    /// "3 keywords", "no keywords".
    static func keywordCountText(_ count: Int) -> String {
        switch count {
        case 0: String(localized: "no keywords")
        case 1: String(localized: "1 keyword")
        default: String(localized: "\(count) keywords")
        }
    }

    private static func fields(of draft: ProductPageDraft, versionString: String?) -> [PendingChangePart] {
        var fields: [(String, String, String)] = [
            ("page.start", String(localized: "Starts from"), draft.start.summary(versionString: versionString, languageCount: draft.locales.count)),
            ("page.locales", String(localized: "Languages with their own content"), draft.locales.map(localeName).formatted(.list(type: .and))),
        ]
        if !draft.deepLink.isEmpty { fields.append(("page.deepLink", ProductPageField.deepLink.title, draft.deepLink)) }
        for locale in draft.locales {
            if let text = draft.promotionalTexts[locale], !text.isEmpty {
                fields.append(("page.\(locale).promotionalText", "\(ProductPageField.promotionalText.title) · \(localeName(locale))", text))
            }
            if let keywords = draft.keywords[locale], !keywords.isEmpty {
                fields.append(("page.\(locale).keywords", "\(ProductPageField.keywords.title) · \(localeName(locale))", keywordsText(keywords)))
            }
        }
        return fields.map { PendingChangePart(id: $0.0, title: $0.1, oldValue: "", newValue: $0.2, source: draft.source) }
    }
}
