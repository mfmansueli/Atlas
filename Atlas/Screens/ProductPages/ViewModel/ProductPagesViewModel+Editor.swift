//
//  ProductPagesViewModel+Editor.swift
//  Atlas
//

import Foundation

// The editor: a page's values with what's queued on top, what can change
// in its review state, and each edit, queued in Review & Push. A draft's
// edits rewrite the draft and the one change that creates it.
extension ProductPagesViewModel {
    // MARK: - Values

    func edits(of page: ProductPage) -> ProductPageEdits {
        page.isDraft ? ProductPageEdits() : builder.edits(for: page.id, in: queue.changes(for: app.id, section: .productPages))
    }

    func draft(of page: ProductPage) -> ProductPageDraft? {
        page.isDraft ? store.draft(for: app.id, id: page.id) : nil
    }

    func text(of page: ProductPage, locale: String) -> String {
        edits(of: page).texts[locale] ?? page.localization(locale)?.promotionalText ?? ""
    }

    func keywords(of page: ProductPage, locale: String) -> [String] {
        edits(of: page).keywords[locale] ?? page.localization(locale)?.keywords ?? []
    }

    func deepLink(of page: ProductPage) -> String {
        edits(of: page).deepLink ?? page.deepLink
    }

    func isVisible(_ page: ProductPage) -> Bool {
        edits(of: page).isVisible ?? page.isVisible
    }

    /// The default page's text in a language: what the page shows without
    /// its own.
    func defaultText(_ locale: String) -> String {
        defaultPage.language(locale)?.promotionalText ?? defaultPage.language(primaryLocale)?.promotionalText ?? ""
    }

    /// Version 1.3's keywords in a language: the only ones to choose from.
    func availableKeywords(_ locale: String) -> [String] {
        defaultPage.language(locale)?.approvedKeywords ?? []
    }

    /// The other page a keyword leads to in a language, if any.
    func keywordOwner(_ keyword: String, locale: String, except pageID: ProductPage.ID) -> ProductPage? {
        pages.first { $0.id != pageID && keywords(of: $0, locale: locale).contains(keyword) }
    }

    /// "4 not pushed": the page's changes in Review & Push.
    func pendingCount(of page: ProductPage) -> Int {
        builder.changes(of: page.id, in: queue.changes(for: app.id, section: .productPages)).count
    }

    // MARK: - What can change

    /// With App Review: nothing changes until it's back.
    func isLocked(_ page: ProductPage) -> Bool {
        page.editing?.state.isLocked ?? false
    }

    /// Approved, and Edit… not pressed: changing it makes a new version.
    func needsNewVersion(_ page: ProductPage) -> Bool {
        guard let editing = page.editing, editing.state.isApproved else { return false }
        return !editingApprovedPageIDs.contains(page.id) && edits(of: page).isEmpty
    }

    /// Its texts, keywords and deep link can change now.
    func canEdit(_ page: ProductPage) -> Bool {
        canChange && !isLocked(page) && !needsNewVersion(page)
    }

    /// Push and Submit…: a draft, a page being prepared or rejected, or a
    /// new version of an approved one.
    func canPushAndSubmit(_ page: ProductPage) -> Bool {
        guard canChange, !isLocked(page) else { return false }
        if page.isDraft { return true }
        switch page.editing?.state {
        case .prepareForSubmission, .readyForReview, .rejected: return true
        case .approved, .accepted: return !edits(of: page).isEmpty
        default: return false
        }
    }

    /// Edit… on an approved page: the fields open, and the push makes
    /// version 2 beside the approved one.
    func startNewVersion(of page: ProductPage) {
        editingApprovedPageIDs.insert(page.id)
    }

    // MARK: - Languages

    /// The page's languages: the primary first, then the default page's
    /// order, with the assistant's and the page's own marked.
    func languages(of page: ProductPage) -> [ProductPageLanguage] {
        var codes = defaultPage.locales
        for code in page.locales + Array(edits(of: page).texts.keys) where !codes.contains(code) { codes.append(code) }
        if let index = codes.firstIndex(of: primaryLocale), index > 0 { codes.insert(codes.remove(at: index), at: 0) }
        if codes.isEmpty { codes = [primaryLocale] }
        let suggested = Set(store.textSuggestions(for: app.id, pageID: page.id).filter { !$0.isRefused }.map(\.locale))
        return codes.map { code in
            if suggested.contains(code), canEdit(page) || page.isDraft { return ProductPageLanguage(code: code, state: .suggested) }
            return ProductPageLanguage(code: code, state: hasOwnContent(page, locale: code) ? .own : .same)
        }
    }

    func hasOwnContent(_ page: ProductPage, locale: String) -> Bool {
        !text(of: page, locale: locale).isEmpty || !keywords(of: page, locale: locale).isEmpty
            || page.localization(locale)?.hasOwnScreenshots == true
    }

    var selectedLanguage: ProductPageLanguage? {
        selectedPage.flatMap { languages(of: $0).first { $0.code == localeCode } }
    }

    // MARK: - Editing

    func editText(_ text: String, source: ChangeSource = .you) {
        guard let page = selectedPage, canEdit(page) else { return }
        write(text: text, locale: localeCode, of: page, source: source)
    }

    func write(text: String, locale: String, of page: ProductPage, source: ChangeSource) {
        if var draft = draft(of: page) {
            draft.promotionalTexts[locale] = text.isEmpty ? nil : text
            if !draft.locales.contains(locale), !text.isEmpty { draft.locales.append(locale) }
            save(draft)
            return
        }
        let id = builder.changeID(pageID: page.id, field: .promotionalText, locale: locale)
        if let change = builder.textChange(text, locale: locale, of: page, source: source) { queue.upsert(change) } else { queue.discard(id: id) }
    }

    /// A chip pressed: chosen ↔ free. One another page has asks first.
    func toggleKeyword(_ keyword: String) {
        guard let page = selectedPage, canEdit(page) else { return }
        var chosen = keywords(of: page, locale: localeCode)
        if let index = chosen.firstIndex(of: keyword) {
            chosen.remove(at: index)
        } else if let owner = keywordOwner(keyword, locale: localeCode, except: page.id) {
            confirmation = .moveKeyword(keyword, locale: localeCode, fromPageID: owner.id, fromName: owner.name)
            return
        } else {
            chosen.append(keyword)
        }
        write(keywords: chosen, locale: localeCode, of: page, source: .you)
    }

    /// Moves a keyword here from the page that had it.
    func moveKeyword(_ keyword: String, locale: String, from ownerID: ProductPage.ID) {
        guard let page = selectedPage, let owner = self.page(ownerID) else { return }
        write(keywords: keywords(of: owner, locale: locale).filter { $0 != keyword }, locale: locale, of: owner, source: .you)
        write(keywords: keywords(of: page, locale: locale) + [keyword], locale: locale, of: page, source: .you)
        show(String(localized: "“\(keyword)” leads to “\(page.name)” now, not “\(owner.name)”."), undo: nil)
    }

    func write(keywords chosen: [String], locale: String, of page: ProductPage, source: ChangeSource) {
        if var draft = draft(of: page) {
            draft.keywords[locale] = chosen.isEmpty ? nil : chosen
            if !draft.locales.contains(locale), !chosen.isEmpty { draft.locales.append(locale) }
            save(draft)
            return
        }
        let id = builder.changeID(pageID: page.id, field: .keywords, locale: locale)
        if let change = builder.keywordsChange(chosen, locale: locale, of: page, source: source) { queue.upsert(change) } else { queue.discard(id: id) }
    }

    func editDeepLink(_ link: String) {
        guard let page = selectedPage, canEdit(page) else { return }
        if var draft = draft(of: page) {
            draft.deepLink = link
            save(draft)
            return
        }
        let id = builder.changeID(pageID: page.id, field: .deepLink)
        if let change = builder.deepLinkChange(link, of: page, source: .you) { queue.upsert(change) } else { queue.discard(id: id) }
    }

    func deepLinkCheck(for page: ProductPage) -> ProductPageDeepLinkCheck {
        let others = pages.filter { $0.id != page.id }.map(deepLink).filter { !$0.isEmpty }
        return ProductPageDeepLinkCheck(link: deepLink(of: page), knownLinks: others, appName: app.name)
    }

    /// Visible: turning it off asks first; on needs no review.
    func setVisible(_ isOn: Bool) {
        guard let page = selectedPage, canChange, page.state.isApproved else { return }
        if !isOn {
            confirmation = .hide(pageID: page.id)
            return
        }
        queueVisible(true, of: page)
        show(String(localized: "“\(page.name)” is visible again. This needs no review."), undo: nil)
    }

    func hide(_ pageID: ProductPage.ID) {
        guard let page = page(pageID) else { return }
        queueVisible(false, of: page)
        show(String(localized: "“\(page.name)” will be hidden when you push. Its link opens the default page."), undo: nil)
    }

    private func queueVisible(_ isOn: Bool, of page: ProductPage) {
        let id = builder.changeID(pageID: page.id, field: .visible)
        if let change = builder.visibleChange(isOn, of: page, source: .you) { queue.upsert(change) } else { queue.discard(id: id) }
    }

    /// Deletes a draft now; a page in App Store Connect when pushed.
    func delete(_ pageID: ProductPage.ID) {
        guard let page = page(pageID) else { return }
        let undo = snapshotForUndo()
        if page.isDraft {
            queue.discard(id: builder.newPageChangeID(draftID: page.id))
            store.removeDrafts([page.id], for: app.id)
            show(String(localized: "“\(page.name)” deleted. It was only in Atlas."), undo: undo)
        } else {
            let builder = builder
            queue.discardAll { builder.isChange($0, of: page.id) }
            queue.upsert(builder.deleteChange(of: page))
            show(String(localized: "“\(page.name)” is deleted when you push. It’s in Review & Push."), undo: undo)
        }
        if selectedPageID == pageID { selectedPageID = nil }
    }

    /// Takes the page's changes out of Review & Push. A draft stays as it
    /// was made.
    func discardChanges(of pageID: ProductPage.ID) {
        guard let page = page(pageID) else { return }
        let undo = snapshotForUndo()
        let builder = builder
        queue.discardAll { builder.isChange($0, of: page.id) && !builder.isNewPage($0) }
        editingApprovedPageIDs.remove(page.id)
        show(String(localized: "Changes to “\(page.name)” discarded."), undo: undo)
    }

    func copyLink(of page: ProductPage) -> URL? {
        guard let url = page.url else { return nil }
        show(String(localized: "Link to “\(page.name)” copied."), undo: nil)
        return url
    }

    // MARK: - Drafts

    func save(_ draft: ProductPageDraft) {
        store.save(draft, for: app.id)
        if let change = builder.newPageChange(draft, defaultPage: defaultPage) { queue.upsert(change) }
    }

    /// New Page…: the draft, opened in the editor.
    @discardableResult
    func create(_ new: NewProductPage) -> ProductPageDraft? {
        guard new.problem(existingNames: pages.map(\.name)) == nil else { return nil }
        let draft = new.draft(id: ProductPageDraft.newID(), now: now())
        save(draft)
        isNewPagePresented = false
        open(draft.id)
        show(String(localized: "“\(draft.name)” is a draft in Atlas. Nothing is in App Store Connect until you push."), undo: nil)
        return draft
    }
}
