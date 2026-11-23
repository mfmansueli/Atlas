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
        var text = String(localized: "“\(suggestion.name)” is a draft. Nothing is public until you push and submit it.")
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
            ? String(localized: "1 draft page added. Nothing is public until you push and submit it.")
            : String(localized: "\(suggestions.count) draft pages added. Nothing is public until you push and submit them.")
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
            id: ProductPageDraft.newID(), name: suggestion.name, start: suggestion.start ?? .defaultPage, note: note,
            locales: ordered.isEmpty ? [primaryLocale] : ordered,
            promotionalTexts: suggestion.promotionalTexts.filter { !$0.value.isEmpty }, keywords: keywords.filter { !$0.value.isEmpty },
            deepLink: suggestion.deepLink, suggestionID: suggestion.id, source: .assistant(client: suggestion.source), createdAt: now()
        )
        save(draft)
        if !suggestion.screens.isEmpty {
            let brief = ProductPageBrief(audience: suggestion.audience, screens: suggestion.screens, source: suggestion.source)
            store.saveBrief(brief, pageName: suggestion.name, for: app.id)
        }
        return left
    }

    /// The brief an accepted suggestion left for the page: who it's for and
    /// the screenshots to add. It stays once the draft is pushed.
    func brief(of page: ProductPage) -> ProductPageBrief? {
        store.archive(for: app.id).brief(named: page.name)
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
        show(String(localized: "Accepted. In Review & Push."), undo: nil)
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
            ? String(localized: "1 suggestion accepted. In Review & Push.")
            : String(localized: "\(suggestions.count) suggestions accepted. In Review & Push.")
        show(text, undo: undo)
    }

    // MARK: - Asking

    /// Suggest Pages / Ask Claude Code for Ideas: where to find who a page
    /// is for, and what makes one worth making. A page reaches people
    /// through search (its keywords; search shows its first screenshots,
    /// not its text) or through a link, so the numbers to read are the
    /// split by source and by market, not only the pages' own.
    var suggestPagesPrompt: String {
        let keywords = defaultPage.approvedVersionString.map { String(localized: "from version \($0)’s keywords") }
            ?? String(localized: "once a version is approved (none is yet, so leave keywords out)")
        return String(localized: """
        Suggest custom product pages for \(app.name) in Atlas. Don't push or submit anything.

        1. Read get_product_pages: the pages and their numbers against the default page, pageLimit, keywords (only \
        keywords.<locale>.free can be chosen) and suggestions. Don't suggest a dismissed page again. To improve a page you \
        suggested that's still open, send it again under the same name.
        2. Find who a page is for, from evidence: get_analytics_funnel; get_analytics_breakdown by source (a page reaches \
        people through search, with the keywords it chooses, or through a link: ads, social posts, the links the app \
        shares), by language and by territory (a large market whose view or download rate is worse than average deserves a \
        page written for it), and by productPage once pages have numbers; get_reviews; get_in_app_events for the seasons \
        ahead. Read this project for what the app really does, its screens, the links it shares and the deep links it opens.
        3. Suggest the 2 to 4 pages most likely to win downloads, best first, each for a different audience. Choose its \
        keywords \(keywords) by what its audience searches in each language: a keyword leads to one page, so leave the broad \
        ones to the default page. Write its promotional text for that audience in every language the app has, in that \
        language's own words. List the screens it should lead with, real ones from the project: search results show its \
        first three screenshots, not its text. Set a deep link only when the project opens it. Give each page its own \
        evidence, with the numbers that point to it.

        Send each with propose_product_page.
        """)
    }

    /// Ask for Another, after a text Atlas stopped in a page's language.
    func askForAnotherPrompt(_ suggestion: ProductPageTextSuggestion) -> String {
        let pageName = page(suggestion.pageID)?.name ?? ""
        return String(localized: """
        Atlas stopped your promotional text for “\(pageName)” in \(ProductPageChangeBuilder.localeName(suggestion.locale)): \
        \(suggestion.refusal) Read get_product_pages (the page's takesTexts and why), then write another with \
        propose_product_page_texts that follows App Review's rules: no price, “free”, discount, trial or other platform.
        """)
    }

    /// Ask for Another, after a text Atlas stopped in a suggested page: the
    /// page is sent again under its name, which replaces the suggestion.
    func askForAnotherPrompt(_ text: ProductPageTextSuggestion, in suggestion: ProductPageSuggestion) -> String {
        String(localized: """
        Atlas stopped the \(ProductPageChangeBuilder.localeName(text.locale)) promotional text of the page you suggested, \
        “\(suggestion.name)”: \(text.refusal) Send “\(suggestion.name)” again with propose_product_page, under the same name, with \
        everything else as it was and a \(ProductPageChangeBuilder.localeName(text.locale)) text that follows App Review's rules: no \
        price, “free”, discount, trial or other platform.
        """)
    }
}
