//
//  MCPProductPages.swift
//  Atlas
//

import Foundation

/// One app's custom product pages as the product page tools see them, the
/// way the Product Pages section shows them: App Store Connect's pages with
/// what's queued in Review & Push on top (a page queued for deletion is
/// gone), the drafts made in Atlas, the suggestions kept on this Mac, and
/// the last 28 days' numbers from Analytics. Proposals are checked against
/// it, so they're checked against what the person sees.
@MainActor
struct MCPProductPages {
    let app: StoreApp
    let snapshot: ProductPagesSnapshot
    let archive: ProductPagesArchive
    /// Review & Push's Product Pages changes for the app.
    let changes: [PendingChange]
    /// Each page's numbers by the name Apple's reports give it, and the
    /// newest day; nil when Analytics has none.
    let numbers: (byPage: [String: ProductPageNumbers], through: AnalyticsDay)?

    static func load(app: StoreApp, workspace: MCPWorkspace, store: ProductPagesStore, analytics: AnalyticsStore) async throws -> MCPProductPages {
        let snapshot = try await workspace.productPages(for: app)
        return MCPProductPages(
            app: app, snapshot: snapshot, archive: store.archive(for: app.id),
            changes: workspace.changes.changes(for: app.id, section: .productPages),
            numbers: ProductPageNumbers.make(from: analytics.archive(for: app.id).pageFacts)
        )
    }

    /// The same pages with the store's suggestions and drafts as they are
    /// now, after a proposal was kept.
    func reading(_ store: ProductPagesStore) -> MCPProductPages {
        MCPProductPages(app: app, snapshot: snapshot, archive: store.archive(for: app.id), changes: changes, numbers: numbers)
    }

    var builder: ProductPageChangeBuilder { ProductPageChangeBuilder(appID: app.id) }

    var defaultPage: ProductPageDefault { snapshot.defaultPage }

    var primaryLocale: String { app.primaryLocale ?? defaultPage.locales.first ?? StoreLocale.englishUS.code }

    // MARK: - Pages

    /// App Store Connect's pages with their queued names, less those queued
    /// for deletion, then the drafts: every one counts toward the limit.
    var pages: [ProductPage] {
        let live = snapshot.pages.compactMap { page -> ProductPage? in
            let edits = edits(of: page)
            guard !edits.isDeleted else { return nil }
            var shown = page
            if let name = edits.name { shown.name = name }
            return shown
        }
        return live + archive.drafts.map(\.page)
    }

    func page(_ id: ProductPage.ID) -> ProductPage? {
        pages.first { $0.id == id }
    }

    /// In App Store Connect still, and deleted when the person pushes.
    func isQueuedForDeletion(_ id: ProductPage.ID) -> Bool {
        snapshot.pages.contains { $0.id == id } && builder.edits(for: id, in: changes).isDeleted
    }

    var pageCount: Int { pages.count }

    func edits(of page: ProductPage) -> ProductPageEdits {
        page.isDraft ? ProductPageEdits() : builder.edits(for: page.id, in: changes)
    }

    func draft(of page: ProductPage) -> ProductPageDraft? {
        page.isDraft ? archive.drafts.first { $0.id == page.id } : nil
    }

    func text(of page: ProductPage, locale: String) -> String {
        edits(of: page).texts[locale] ?? page.localization(locale)?.promotionalText ?? ""
    }

    func keywords(of page: ProductPage, locale: String) -> [String] {
        edits(of: page).keywords[locale] ?? page.localization(locale)?.keywords ?? []
    }

    func isVisible(_ page: ProductPage) -> Bool {
        edits(of: page).isVisible ?? page.isVisible
    }

    // MARK: - Languages and keywords

    /// The App Store code for `code` when the app's pages can have it: one
    /// of the default page's languages (any App Store language before
    /// there are any).
    func locale(_ code: String) -> String? {
        guard let locale = StoreLocaleCatalog.locale(code: code)?.code else { return nil }
        return defaultPage.locales.isEmpty || defaultPage.locales.contains(locale) ? locale : nil
    }

    /// The last approved version's keyword spelled like `keyword`, case
    /// ignored; nil when the version doesn't have it in that language.
    func approvedKeyword(_ keyword: String, locale: String) -> String? {
        defaultPage.language(locale)?.approvedKeywords.first { $0.caseInsensitiveCompare(keyword) == .orderedSame }
    }

    /// The page a keyword leads to in a language, other than `pageID`.
    func keywordOwner(_ keyword: String, locale: String, except pageID: ProductPage.ID? = nil) -> ProductPage? {
        pages.first { page in
            page.id != pageID && keywords(of: page, locale: locale).contains { $0.caseInsensitiveCompare(keyword) == .orderedSame }
        }
    }

    // MARK: - Suggested texts

    /// Why a page can't take a suggested promotional text now; nil when it
    /// can.
    func textBlocker(_ page: ProductPage) -> String? {
        if archive.keyCannotChange {
            return String(localized: "The API key can read product pages but not change them, so the person can’t accept texts.")
        }
        if page.editing?.state.isLocked == true {
            return String(localized: "“\(page.name)” is with App Review: nothing on it can change until Apple is done.")
        }
        return nil
    }

    /// What the person does before an approved page's suggestion shows:
    /// Edit…, which makes a new version. Nil for every other page.
    func newVersionNote(_ page: ProductPage) -> String? {
        guard let editing = page.editing, editing.state.isApproved, edits(of: page).isEmpty else { return nil }
        return String(localized: """
        “\(page.name)” is approved: a suggested text shows once the person presses Edit… on it, and accepting it makes \
        version \(editing.number + 1), which App Review approves before it replaces version \(editing.number).
        """)
    }

    // MARK: - Numbers

    /// A page's last 28 days, when Analytics has them.
    func numbers(of page: ProductPage) -> ProductPageNumbers? {
        guard !page.isDraft, let numbers = numbers?.byPage[page.name], numbers.impressions > 0 else { return nil }
        return numbers
    }

    var defaultNumbers: ProductPageNumbers? { numbers?.byPage[ProductPageNumbers.defaultPageName] }

    /// Whether any custom page has numbers to compare yet.
    var hasPageNumbers: Bool { pages.contains { numbers(of: $0) != nil } }

    // MARK: - The limit

    /// Pages, suggested pages waiting, and how many more there's room for.
    var limitJSON: JSONValue {
        let waiting = archive.openPageSuggestions.count
        return [
            "pages": .int(pageCount),
            "limit": .int(ProductPagesSnapshot.limit),
            "suggestedPagesWaiting": .int(waiting),
            "roomFor": .int(max(0, ProductPagesSnapshot.limit - pageCount - waiting)),
        ]
    }
}
