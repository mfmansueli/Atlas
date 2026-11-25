//
//  MCPProductPageEdit.swift
//  Atlas
//

import Foundation

/// What `propose_product_page_edit` asks of one page, and the changes it
/// becomes, checked as the page's editor checks them: an approved keyword
/// no other page uses, a complete deep link, a name no other page has,
/// visible only once approved, and delete alone.
struct MCPProductPageEdit: Hashable, Sendable {
    var name: String?
    var deepLink: String?
    /// Locale as sent → the whole keyword list there.
    var keywords: [String: [String]] = [:]
    var visible: Bool?
    var delete = false

    /// The changes to queue, the ones to drop (back to today's) and every
    /// problem, which refuses the whole call.
    struct Plan {
        var changes: [PendingChange] = []
        var discards: [PendingChange.ID] = []
        var problems: [String] = []
    }

    init(name: String? = nil, deepLink: String? = nil, keywords: [String: [String]] = [:], visible: Bool? = nil, delete: Bool = false) {
        self.name = name
        self.deepLink = deepLink
        self.keywords = keywords
        self.visible = visible
        self.delete = delete
    }

    init(_ arguments: MCPToolArguments) throws {
        name = try arguments.optionalString("name")
        deepLink = try arguments.optionalString("deepLink")
        visible = try arguments.optionalBool("visible")
        delete = try arguments.optionalBool("delete") ?? false
        if let object = try arguments.optionalObject("keywords") {
            for (locale, value) in object {
                guard let list = value.arrayValue?.compactMap(\.stringValue), list.count == value.arrayValue?.count else {
                    throw MCPToolError.invalidArgument(name: "keywords", expected: String(localized: "locale → a list of keywords"))
                }
                keywords[locale] = list
            }
        }
    }

    var isEmpty: Bool {
        name == nil && deepLink == nil && keywords.isEmpty && visible == nil && !delete
    }

    @MainActor
    func plan(page: ProductPage, state: MCPProductPages, queue: ChangeQueue, source: ChangeSource) -> Plan {
        var plan = Plan()
        let builder = state.builder
        if delete {
            guard name == nil, deepLink == nil, keywords.isEmpty, visible == nil else {
                plan.problems.append(String(localized: "Send delete alone: a deleted page takes no other change."))
                return plan
            }
            let theirs = queue.changes(for: state.app.id).filter { builder.isChange($0, of: page.id) && $0.source != source }
            guard theirs.isEmpty else {
                plan.problems.append(String(localized: """
                The person has \(theirs.count) changes for “\(page.name)” in Review & Push. Deleting would drop them, so \
                only the person deletes it now.
                """))
                return plan
            }
            var change = builder.deleteChange(of: page)
            change.source = source
            change.awaitingAcceptance = String(localized: "Deletes “\(page.name)” and its link, which then opens the default page. Accept it to push it.")
            plan.changes.append(change)
            return plan
        }
        if let name { addName(name, page: page, state: state, source: source, to: &plan) }
        if let deepLink { addDeepLink(deepLink, page: page, state: state, source: source, to: &plan) }
        for (code, list) in keywords.sorted(by: { $0.key < $1.key }) {
            addKeywords(list, locale: code, page: page, state: state, source: source, to: &plan)
        }
        if let visible {
            if page.state.isApproved {
                let id = builder.changeID(pageID: page.id, field: .visible)
                if let change = builder.visibleChange(visible, of: page, source: source) { plan.changes.append(change) } else { plan.discards.append(id) }
            } else {
                plan.problems.append(String(localized: "“\(page.name)” isn’t approved yet: only an approved page shows or hides."))
            }
        }
        return plan
    }

    // MARK: - Private

    /// An approved page's keywords and deep link change in a new version,
    /// which only the person starts (Edit… on the page).
    @MainActor
    static func newVersionProblem(_ page: ProductPage, state: MCPProductPages) -> String? {
        guard state.newVersionNote(page) != nil else { return nil }
        return String(localized: """
        “\(page.name)” is approved: its keywords and deep link change in a new version, which the person starts with \
        Edit… on the page. Ask them, then send this again.
        """)
    }

    @MainActor
    private func addName(_ name: String, page: ProductPage, state: MCPProductPages, source: ChangeSource, to plan: inout Plan) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return plan.problems.append(String(localized: "A page needs a name.")) }
        if state.pages.contains(where: { $0.id != page.id && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return plan.problems.append(String(localized: "Another page is called “\(trimmed)”. Pick a name no page has."))
        }
        let builder = state.builder
        if let change = builder.nameChange(trimmed, of: page, source: source) {
            plan.changes.append(change)
        } else {
            plan.discards.append(builder.changeID(pageID: page.id, field: .name))
        }
    }

    @MainActor
    private func addDeepLink(_ link: String, page: ProductPage, state: MCPProductPages, source: ChangeSource, to plan: inout Plan) {
        if let problem = Self.newVersionProblem(page, state: state) { return plan.problems.append(problem) }
        let others = state.pages.filter { $0.id != page.id }.map(\.deepLink).filter { !$0.isEmpty }
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let problem = ProductPageDeepLinkCheck(link: trimmed, knownLinks: others, appName: state.app.name).blockingProblem {
            return plan.problems.append(problem)
        }
        let builder = state.builder
        if let change = builder.deepLinkChange(trimmed, of: page, source: source) {
            plan.changes.append(change)
        } else {
            plan.discards.append(builder.changeID(pageID: page.id, field: .deepLink))
        }
    }

    @MainActor
    private func addKeywords(_ list: [String], locale code: String, page: ProductPage, state: MCPProductPages, source: ChangeSource, to plan: inout Plan) {
        if let problem = Self.newVersionProblem(page, state: state) { return plan.problems.append(problem) }
        guard let locale = state.locale(code) else {
            return plan.problems.append(String(localized: "\(state.app.name) has no language “\(code)”. Use the locales get_product_pages lists."))
        }
        var chosen: [String] = []
        for keyword in list {
            guard let approved = state.approvedKeyword(keyword, locale: locale) else {
                plan.problems.append(String(localized: "“\(keyword)” isn’t one of the approved version’s keywords in \(locale)."))
                continue
            }
            if let owner = state.keywordOwner(approved, locale: locale, except: page.id) {
                plan.problems.append(String(localized: "“\(approved)” leads to “\(owner.name)” in \(locale). One keyword leads to one page."))
                continue
            }
            if !chosen.contains(approved) { chosen.append(approved) }
        }
        let builder = state.builder
        if let change = builder.keywordsChange(chosen, locale: locale, of: page, source: source) {
            plan.changes.append(change)
        } else {
            plan.discards.append(builder.changeID(pageID: page.id, field: .keywords, locale: locale))
        }
    }
}
