//
//  ProductPageChangeBuilder.swift
//  Atlas
//

import Foundation

/// Turns edits to a custom product page into Review & Push changes, and
/// reads queued changes back, so the queue is where edits live.
///
/// - A language's promotional text, a language's keywords and the deep link
///   go into the page's version that takes edits (`ProductPageLocaleWrite`):
///   for an approved page, that's a new version the push makes.
/// - The name and Visible are the page's own (`PATCH /v1/appCustomProductPages`).
/// - A language's own screenshots on one device are uploaded into its set
///   (`ProductPageScreenshotsPush`).
/// - Ids are `productPages.<appID>.<pageID>.<field>`, or
///   `….<pageID>.<locale>.<field>` per language, or
///   `….<pageID>.<locale>.<displayType>.screenshots`.
struct ProductPageChangeBuilder: Hashable, Sendable {
    let appID: StoreApp.ID

    static let pageType = "appCustomProductPages"

    var idPrefix: String { "productPages.\(appID)." }

    func owns(_ change: PendingChange) -> Bool {
        change.section == .productPages && change.appID == appID && change.id.hasPrefix(idPrefix)
    }

    func changeID(pageID: ProductPage.ID, field: ProductPageField, locale: String? = nil) -> String {
        if let locale, field.isPerLanguage { return "\(idPrefix)\(pageID).\(locale).\(field.rawValue)" }
        return "\(idPrefix)\(pageID).\(field.rawValue)"
    }

    func isChange(_ change: PendingChange, of pageID: ProductPage.ID) -> Bool {
        owns(change) && change.id.hasPrefix("\(idPrefix)\(pageID).")
    }

    /// "Product Pages · Private diary".
    func group(_ name: String) -> String {
        String(localized: "Custom Product Pages · \(name)")
    }

    // MARK: - Changes

    /// One language's promotional text; nil when it's what the page has.
    func textChange(_ text: String, locale: String, of page: ProductPage, source: ChangeSource) -> PendingChange? {
        let old = page.localization(locale)?.promotionalText ?? ""
        guard text != old else { return nil }
        let write = ProductPageLocaleWrite(.init(pageID: page.id, currentDeepLink: page.deepLink, locale: locale, promotionalText: text))
        let restore = ProductPageLocaleWrite(.init(pageID: page.id, currentDeepLink: page.deepLink, locale: locale, promotionalText: old))
        return PendingChange(
            id: changeID(pageID: page.id, field: .promotionalText, locale: locale),
            appID: appID, section: .productPages, group: group(page.name), groupID: page.id,
            title: "\(Self.localeName(locale)) · \(ProductPageField.promotionalText.title)", flagRegion: Self.region(locale),
            oldValue: old, newValue: text, source: source, blockedReason: Self.textProblem(text),
            requests: [write.request], restoreRequests: [restore.request]
        )
    }

    /// One language's keywords, in the order chosen; nil when they're the
    /// page's.
    func keywordsChange(_ chosen: [String], locale: String, of page: ProductPage, source: ChangeSource) -> PendingChange? {
        let old = page.localization(locale)?.keywords ?? []
        guard Set(chosen) != Set(old) else { return nil }
        let added = chosen.filter { !old.contains($0) }
        let removed = old.filter { !chosen.contains($0) }
        let write = ProductPageLocaleWrite(.init(
            pageID: page.id, currentDeepLink: page.deepLink, locale: locale, addKeywords: added, removeKeywords: removed
        ))
        let restore = ProductPageLocaleWrite(.init(
            pageID: page.id, currentDeepLink: page.deepLink, locale: locale, addKeywords: removed, removeKeywords: added
        ))
        return PendingChange(
            id: changeID(pageID: page.id, field: .keywords, locale: locale),
            appID: appID, section: .productPages, group: group(page.name), groupID: page.id,
            title: "\(Self.localeName(locale)) · \(ProductPageField.keywords.title)", flagRegion: Self.region(locale),
            oldValue: Self.keywordsText(old), newValue: Self.keywordsText(chosen), source: source,
            requests: [write.request], restoreRequests: [restore.request]
        )
    }

    func deepLinkChange(_ link: String, of page: ProductPage, source: ChangeSource) -> PendingChange? {
        let old = page.deepLink
        guard link != old else { return nil }
        let write = ProductPageLocaleWrite(.init(pageID: page.id, currentDeepLink: old, deepLink: link))
        return PendingChange(
            id: changeID(pageID: page.id, field: .deepLink),
            appID: appID, section: .productPages, group: group(page.name), groupID: page.id,
            title: ProductPageField.deepLink.title, oldValue: old, newValue: link, source: source,
            blockedReason: ProductPageDeepLinkCheck(link: link, domains: []).blockingProblem,
            requests: [write.request], restoreRequests: [ProductPageLocaleWrite(.init(pageID: page.id, currentDeepLink: link, deepLink: old)).request]
        )
    }

    func nameChange(_ name: String, of page: ProductPage, source: ChangeSource) -> PendingChange? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != page.name else { return nil }
        return PendingChange(
            id: changeID(pageID: page.id, field: .name),
            appID: appID, section: .productPages, group: group(page.name), groupID: page.id,
            title: ProductPageField.name.title, oldValue: page.name, newValue: trimmed, source: source,
            blockedReason: trimmed.isEmpty ? String(localized: "A page needs a name.") : nil,
            requests: [pageUpdate(page.id, ["name": trimmed])], restoreRequests: [pageUpdate(page.id, ["name": page.name])]
        )
    }

    func visibleChange(_ isVisible: Bool, of page: ProductPage, source: ChangeSource) -> PendingChange? {
        guard isVisible != page.isVisible else { return nil }
        return PendingChange(
            id: changeID(pageID: page.id, field: .visible),
            appID: appID, section: .productPages, group: group(page.name), groupID: page.id,
            title: ProductPageField.visible.title, oldValue: Self.visibleText(page.isVisible), newValue: Self.visibleText(isVisible),
            source: source,
            requests: [pageUpdate(page.id, ["visible": isVisible])], restoreRequests: [pageUpdate(page.id, ["visible": page.isVisible])]
        )
    }

    func deleteChange(of page: ProductPage) -> PendingChange {
        PendingChange(
            id: changeID(pageID: page.id, field: .delete),
            appID: appID, section: .productPages, group: group(page.name), groupID: page.id,
            title: String(localized: "Delete “\(page.name)”"), oldValue: page.name, newValue: "",
            requests: [PushRequest(method: .delete, path: "/v1/\(Self.pageType)/\(page.id)")]
        )
    }

    // MARK: - Reading back

    /// What's queued for a page.
    func edits(for pageID: ProductPage.ID, in changes: [PendingChange]) -> ProductPageEdits {
        var edits = ProductPageEdits()
        let prefix = "\(idPrefix)\(pageID)."
        for change in changes where owns(change) && change.id.hasPrefix(prefix) {
            let rest = change.id.dropFirst(prefix.count).split(separator: ".").map(String.init)
            guard let last = rest.last, let field = ProductPageField(rawValue: last) else { continue }
            edits.count += 1
            if field == .screenshots || field == .appPreviews {
                addScreenshots(of: change, to: &edits)
                continue
            }
            let locale = rest.count > 1 ? rest.dropLast().joined(separator: ".") : nil
            Self.apply(field, value: change.newValue, locale: locale, to: &edits)
        }
        return edits
    }

    /// One change's field into `edits` (screenshots are read apart).
    private static func apply(_ field: ProductPageField, value: String, locale: String?, to edits: inout ProductPageEdits) {
        switch field {
        case .promotionalText: if let locale { edits.texts[locale] = value }
        case .keywords: if let locale { edits.keywords[locale] = keywords(in: value) }
        case .deepLink: edits.deepLink = value
        case .name: edits.name = value
        case .visible: edits.isVisible = value == visibleText(true)
        case .delete: edits.isDeleted = true
        case .screenshots, .appPreviews: break
        }
    }

    /// Every queued change of a page.
    func changes(of pageID: ProductPage.ID, in changes: [PendingChange]) -> [PendingChange] {
        changes.filter { isChange($0, of: pageID) }
    }

    // MARK: - Helpers

    private func pageUpdate(_ pageID: ProductPage.ID, _ attributes: [String: Any]) -> PushRequest {
        let body: [String: Any] = ["data": ["type": Self.pageType, "id": pageID, "attributes": attributes]]
        let data = (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()
        return PushRequest(method: .patch, path: "/v1/\(Self.pageType)/\(pageID)", body: data)
    }

    static func keywordsText(_ keywords: [String]) -> String {
        keywords.joined(separator: ", ")
    }

    static func keywords(in text: String) -> [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    static func visibleText(_ isVisible: Bool) -> String {
        isVisible ? String(localized: "Visible") : String(localized: "Hidden")
    }

    /// "Promotional Text is 174 characters; the limit is 170."
    static func textProblem(_ text: String) -> String? {
        let limit = ProductPageField.promotionalTextLimit
        return text.count > limit ? String(localized: "Promotional Text is \(text.count) characters; the limit is \(limit).") : nil
    }

    static func localeName(_ code: String) -> String {
        StoreLocaleCatalog.locale(code: code)?.name ?? code
    }

    static func region(_ code: String) -> String? {
        StoreLocaleCatalog.locale(code: code)?.regionCode
    }
}
