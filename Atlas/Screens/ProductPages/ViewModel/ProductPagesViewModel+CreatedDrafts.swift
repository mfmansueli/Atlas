//
//  ProductPagesViewModel+CreatedDrafts.swift
//  Atlas
//

import Foundation

// A draft App Store Connect made although its push didn't finish (Apple
// answered after Atlas stopped waiting, or a later write failed): the page
// is there under the draft's name, still being prepared, while the draft's
// create change is still queued. Sending it again would make a second
// page, so the draft becomes that page: what the draft says that the page
// doesn't (each language's text and keywords, the deep link) waits in
// Review & Push as changes to it.
extension ProductPagesViewModel {
    /// The drafts that are in App Store Connect now, each with its page.
    func createdDrafts(in pages: [ProductPage]) -> [(draft: ProductPageDraft, page: ProductPage)] {
        let queued = Set(queue.changes(for: app.id, section: .productPages).map(\.id))
        return store.drafts(for: app.id).compactMap { draft in
            guard queued.contains(builder.newPageChangeID(draftID: draft.id)) else { return nil }
            let key = ProductPageBrief.key(draft.name)
            guard let page = pages.first(where: {
                !$0.isDraft && ProductPageBrief.key($0.name) == key && $0.state == .prepareForSubmission
            }) else { return nil }
            return (draft, page)
        }
    }

    /// Turns each created draft into changes to its page; returns their
    /// names.
    @discardableResult
    func adoptCreatedDrafts(in pages: [ProductPage]) -> [String] {
        let found = createdDrafts(in: pages)
        guard !found.isEmpty else { return [] }
        for (draft, page) in found {
            queue.discard(id: builder.newPageChangeID(draftID: draft.id))
            queue.upsert(contentsOf: changes(bringing: draft, to: page))
            if selectedPageID == draft.id { selectedPageID = page.id }
        }
        store.removeDrafts(Set(found.map(\.draft.id)), for: app.id)
        let names = found.map(\.page.name)
        show(names.count == 1
            ? String(localized: "“\(names[0])” is in App Store Connect. What it still needs from the draft is in Review & Push.")
            : String(localized: "\(names.count) pages are in App Store Connect. What they still need from their drafts is in Review & Push."),
            undo: nil)
        return names
    }

    /// The draft's texts, keywords and deep link the page doesn't have yet.
    func changes(bringing draft: ProductPageDraft, to page: ProductPage) -> [PendingChange] {
        var changes: [PendingChange] = []
        for locale in draft.locales {
            if let text = draft.promotionalTexts[locale], !text.isEmpty,
               let change = builder.textChange(text, locale: locale, of: page, source: draft.source)
            {
                changes.append(change)
            }
            if let keywords = draft.keywords[locale], !keywords.isEmpty,
               let change = builder.keywordsChange(keywords, locale: locale, of: page, source: draft.source)
            {
                changes.append(change)
            }
        }
        let link = draft.deepLink.trimmingCharacters(in: .whitespaces)
        if !link.isEmpty, let change = builder.deepLinkChange(link, of: page, source: draft.source) { changes.append(change) }
        return changes
    }
}
