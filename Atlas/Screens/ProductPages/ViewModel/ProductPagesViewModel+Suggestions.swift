//
//  ProductPagesViewModel+Suggestions.swift
//  Atlas
//

import Foundation

// What an assistant suggested over MCP: whole pages, accepted as drafts,
// and one language's promotional text, accepted into Review & Push. A text
// Atlas stopped is shown as "Not offered" and can't be accepted.
extension ProductPagesViewModel {
    // MARK: - Pages

    var pageSuggestions: [ProductPageSuggestion] {
        guard state.value != nil, canMakePages else { return [] }
        return store.pageSuggestions(for: app.id)
    }

    /// "2 pages suggested".
    var pageSuggestionsTitle: String {
        let count = pageSuggestions.count
        return count == 1 ? String(localized: "1 page suggested") : String(localized: "\(count) pages suggested")
    }

    func acceptPage(_ suggestion: ProductPageSuggestion) {
        let undo = snapshotForUndo()
        let left = makeDraft(from: suggestion)
        store.removeSuggestions([suggestion.id], for: app.id)
        if expandedSuggestionID == suggestion.id { expandedSuggestionID = nil }
        var text = String(localized: "“\(suggestion.name)” is now a draft page. Nothing is on the App Store until you push and submit it.")
        if !left.isEmpty { text += " " + Self.leftOutText(left) }
        show(text, undo: undo)
    }

    func acceptAllPages() {
        let suggestions = pageSuggestions
        guard !suggestions.isEmpty else { return }
        let undo = snapshotForUndo()
        var left: [(String, String)] = []
        for suggestion in suggestions {
            left += makeDraft(from: suggestion)
        }
        store.removeSuggestions(Set(suggestions.map(\.id)), for: app.id)
        expandedSuggestionID = nil
        var text = suggestions.count == 1
            ? String(localized: "1 page added as a draft. Nothing is on the App Store until you push and submit it.")
            : String(localized: "\(suggestions.count) pages added as drafts. Nothing is on the App Store until you push and submit them.")
        if !left.isEmpty { text += " " + Self.leftOutText(left) }
        show(text, undo: undo)
    }

    func dismissPage(_ suggestion: ProductPageSuggestion) {
        let undo = snapshotForUndo()
        store.dismiss(suggestion.id, for: app.id)
        if expandedSuggestionID == suggestion.id { expandedSuggestionID = nil }
        show(String(localized: "Suggestion dismissed."), undo: undo)
    }

    /// The draft a suggestion makes. A keyword leads to one page, so one
    /// another page has is left out; returns those, with that page's name.
    @discardableResult
    private func makeDraft(from suggestion: ProductPageSuggestion) -> [(keyword: String, page: String)] {
        let known = Set(defaultPage.locales)
        var locales = Set(suggestion.promotionalTexts.filter { !$0.value.isEmpty }.keys).union(suggestion.keywords.keys)
        if !known.isEmpty { locales.formIntersection(known) }
        let ordered = defaultPage.locales.filter(locales.contains) + locales.subtracting(defaultPage.locales).sorted()
        var left: [(String, String)] = []
        var keywords: [String: [String]] = [:]
        for (locale, words) in suggestion.keywords {
            let allowed = Set(availableKeywords(locale))
            keywords[locale] = words.filter { word in
                if let owner = keywordOwner(word, locale: locale, except: "") {
                    left.append((word, owner.name))
                    return false
                }
                return allowed.isEmpty || allowed.contains(word)
            }
        }
        let note = [suggestion.audience, suggestion.screens.isEmpty ? "" : String(localized: "Screenshots: \(suggestion.screens)")]
            .filter { !$0.isEmpty }.joined(separator: "\n")
        let draft = ProductPageDraft(
            id: ProductPageDraft.newID(), name: suggestion.name, start: .defaultPage, note: note,
            locales: ordered.isEmpty ? [primaryLocale] : ordered,
            promotionalTexts: suggestion.promotionalTexts.filter { !$0.value.isEmpty }, keywords: keywords.filter { !$0.value.isEmpty },
            deepLink: suggestion.deepLink, suggestionID: suggestion.id, source: .assistant(client: suggestion.source), createdAt: now()
        )
        save(draft)
        return left
    }

    /// "“habit” is on “Mood tracking”, so it was left out."
    private static func leftOutText(_ left: [(keyword: String, page: String)]) -> String {
        guard let first = left.first else { return "" }
        if left.count == 1 { return String(localized: "“\(first.keyword)” is on “\(first.page)”, so it was left out.") }
        return String(localized: "\(left.count) keywords other pages have were left out.")
    }

    // MARK: - Texts

    /// The suggestion for the editor's language, accepted or not offered.
    var textSuggestion: ProductPageTextSuggestion? {
        guard let page = selectedPage, canEdit(page) else { return nil }
        return store.textSuggestion(for: app.id, pageID: page.id, locale: localeCode)
    }

    /// Languages of the page with a text that can be accepted.
    func acceptableTextSuggestions(of page: ProductPage) -> [ProductPageTextSuggestion] {
        guard canEdit(page) else { return [] }
        return store.textSuggestions(for: app.id, pageID: page.id).filter { !$0.isRefused }
    }

    /// "2 languages have a suggestion · the others use the default page’s
    /// text and screenshots".
    func languageHeadline(of page: ProductPage) -> String {
        let count = acceptableTextSuggestions(of: page).count
        let others = String(localized: "the others use the default page’s text and screenshots")
        if count > 0 {
            let lead = count == 1 ? String(localized: "1 language has a suggestion") : String(localized: "\(count) languages have a suggestion")
            return "\(lead) · \(others)"
        }
        let own = languages(of: page).filter { $0.state == .own }.map(\.name)
        guard !own.isEmpty else { return String(localized: "Every language uses the default page’s text and screenshots") }
        if own.count <= 2 { return String(localized: "Own text in \(own.formatted(.list(type: .and))) · \(others)") }
        return String(localized: "No suggestions waiting · \(others)")
    }

    func acceptText(_ suggestion: ProductPageTextSuggestion) {
        guard !suggestion.isRefused, let page = page(suggestion.pageID), canEdit(page) else { return }
        write(text: suggestion.text, locale: suggestion.locale, of: page, source: .assistant(client: suggestion.source))
        store.removeSuggestions([suggestion.id], for: app.id)
        show(String(localized: "Accepted. It’s in Review & Push."), undo: nil)
    }

    /// Use and Edit: the text goes into the field, as the person's.
    func useAndEdit(_ suggestion: ProductPageTextSuggestion) {
        guard !suggestion.isRefused, let page = page(suggestion.pageID), canEdit(page) else { return }
        write(text: suggestion.text, locale: suggestion.locale, of: page, source: .you)
        store.removeSuggestions([suggestion.id], for: app.id)
    }

    func dismissText(_ suggestion: ProductPageTextSuggestion) {
        store.dismiss(suggestion.id, for: app.id)
    }

    func acceptAllLanguages() {
        guard let page = selectedPage else { return }
        let suggestions = acceptableTextSuggestions(of: page)
        guard !suggestions.isEmpty else { return }
        let undo = snapshotForUndo()
        for suggestion in suggestions {
            write(text: suggestion.text, locale: suggestion.locale, of: page, source: .assistant(client: suggestion.source))
        }
        store.removeSuggestions(Set(suggestions.map(\.id)), for: app.id)
        let text = suggestions.count == 1
            ? String(localized: "1 suggestion accepted. It’s in Review & Push.")
            : String(localized: "\(suggestions.count) suggestions accepted. They’re in Review & Push.")
        show(text, undo: undo)
    }

    // MARK: - Asking

    /// Suggest Pages / Ask Claude Code for Ideas.
    var suggestPagesPrompt: String {
        let version = defaultPage.approvedVersionString.map { String(localized: "version \($0)’s keywords") } ?? String(localized: "the store page")
        return String(localized: """
        Suggest custom product pages for \(app.name) in Atlas. Read get_product_pages first (the pages it has, their numbers and \
        \(version)), then get_reviews and get_analytics_breakdown (dimension productPage) for evidence. Send each page with \
        propose_product_page: who it's for, why (with evidence Atlas can show), keywords from \(version) that no other page has, \
        promotional text in each language and what the screenshots should show first. Don't push or submit anything.
        """)
    }

    /// Ask for Another, after a text Atlas stopped.
    func askForAnotherPrompt(_ suggestion: ProductPageTextSuggestion) -> String {
        let pageName = page(suggestion.pageID)?.name ?? ""
        return String(localized: """
        Atlas stopped your promotional text for “\(pageName)” in \(ProductPageChangeBuilder.localeName(suggestion.locale)): \
        \(suggestion.refusal) Write another with propose_product_page_texts that follows App Review's rules: no price, “free”, \
        discount, trial or other platform.
        """)
    }
}
