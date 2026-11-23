//
//  ProductPageProposal.swift
//  Atlas
//

import Foundation

/// `propose_product_page`'s arguments as a suggested page, checked against
/// the app's pages the way the section would make it: a name no other page
/// has, evidence Atlas can show, keywords only from the approved version
/// and none another page leads to, promotional text within 170 characters
/// in the app's languages, a complete deep link, captions without what App
/// Review rejects, and room under the 70 pages. Every problem is listed
/// with how to fix it. A text that breaks App Review's rules isn't a
/// problem: it's kept as Not offered.
@MainActor
struct ProductPageProposal {
    static let audienceLimit = 200
    static let reasonLimit = AssistantTextLimits.why
    static let screensLimit = 600
    static let idPrefix = "pp-"

    var suggestion: ProductPageSuggestion
    /// The texts Atlas stopped, with the rules each breaks.
    var notOffered: [(locale: String, text: String, issues: [StoreTextGuidelineIssue])] = []
    /// What stops it, each saying how to fix it.
    var problems: [String] = []
    /// The suggestion it replaces: the same name, from the same assistant.
    var replaces: String?

    /// The app's languages that would show the default page's text.
    var languagesWithoutText: [String] = []

    static func make(
        _ arguments: MCPToolArguments, state: MCPProductPages, source: String, analytics: AnalyticsStore, reviews: ReviewsStore
    ) throws -> ProductPageProposal {
        let name = try arguments.string("name")
        let audience = try arguments.string("audience")
        let reason = try arguments.string("reason")
        let evidence = try MCPProductPageEvidence.read(arguments.values["evidence"])
        var proposal = ProductPageProposal(suggestion: ProductPageSuggestion(
            id: "", name: name, audience: audience, reason: reason, evidence: evidence, source: source
        ))
        proposal.suggestion.layers = try arguments.layers()
        proposal.checkName(in: state)
        proposal.checkLengths()
        proposal.suggestion.start = try Self.start(arguments.optionalString("startFrom"), in: state)
        try proposal.readKeywords(arguments.optionalObject("keywords"), in: state)
        try proposal.readTexts(arguments.optionalObject("promotionalText"), in: state)
        if proposal.suggestion.promotionalTexts.isEmpty, proposal.notOffered.isEmpty, proposal.suggestion.keywords.isEmpty {
            proposal.problems.append(String(localized: """
            Send promotionalText in the app's languages (or keywords): a page with neither looks just like the default page.
            """))
        }
        let deepLink = try arguments.optionalString("deepLink")
        proposal.readDeepLink(deepLink, in: state)
        try proposal.readScreens(arguments.values["screens"])
        proposal.checkEvidence(state: state, analytics: analytics, reviews: reviews)
        proposal.checkLimit(in: state)
        proposal.suggestion.id = proposal.replaces ?? idPrefix + UUID().uuidString.lowercased()
        if !proposal.notOffered.isEmpty {
            proposal.suggestion.notOfferedTexts = proposal.notOffered.map { item in
                MCPPromotionalText.refused(
                    pageID: proposal.suggestion.id, locale: item.locale, text: item.text, issues: item.issues, reason: "", source: source
                )
            }
        }
        proposal.languagesWithoutText = state.defaultPage.locales.filter { proposal.suggestion.promotionalTexts[$0] == nil }
        return proposal
    }

    // MARK: - Checks

    private mutating func checkName(in state: MCPProductPages) {
        let name = suggestion.name
        if let page = state.pages.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            let kind = page.isDraft ? String(localized: "a draft in Atlas") : String(localized: "a page in App Store Connect")
            problems.append(String(localized: "“\(page.name)” is already \(kind): choose another name, or suggest its texts with propose_product_page_texts."))
            return
        }
        let same = state.archive.pageSuggestions.filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        if same.contains(where: { state.archive.dismissed.contains($0.id) }) {
            problems.append(String(localized: "The person dismissed a suggested page called “\(name)”. Don't suggest it again; suggest another page."))
        } else if let other = same.first(where: { $0.source != suggestion.source }) {
            problems.append(String(localized: "\(other.source) already suggested a page called “\(name)”: leave it for the person, or suggest another page."))
        } else {
            replaces = same.first?.id
        }
    }

    private mutating func checkLengths() {
        if suggestion.audience.count > Self.audienceLimit {
            problems.append(String(localized: "audience has \(suggestion.audience.count) characters; it holds \(Self.audienceLimit): say who it's for in a sentence."))
        }
        if let refusal = AssistantTextLimits.whyRefusal(suggestion.reason, field: "reason") {
            problems.append(refusal)
        }
    }

    private mutating func checkEvidence(state: MCPProductPages, analytics: AnalyticsStore, reviews: ReviewsStore) {
        guard !suggestion.evidence.isEmpty else {
            problems.append(String(localized: """
            A suggested page needs evidence Atlas can show the person, or it isn't listed: evidence [{source: analytics, \
            reviews or keywords, detail}], e.g. numbers from get_analytics_breakdown (by source, language, territory or \
            productPage), what reviews from get_reviews say, or the approved version's keywords it chooses.
            """))
            return
        }
        problems += MCPProductPageEvidence.problems(
            suggestion.evidence, app: state.app, keywordsChosen: !suggestion.keywords.isEmpty,
            hasApprovedVersion: state.defaultPage.hasApprovedVersion, analytics: analytics, reviews: reviews
        )
    }

    private mutating func checkLimit(in state: MCPProductPages) {
        let limit = ProductPagesSnapshot.limit
        if state.pageCount >= limit {
            problems.append(String(localized: """
            \(state.app.name) has \(state.pageCount) of \(limit) pages, the most Apple allows (drafts, hidden and rejected \
            pages count): the person deletes one before another can be made.
            """))
            return
        }
        let waiting = state.archive.openPageSuggestions.count { $0.id != replaces }
        if state.pageCount + waiting >= limit {
            problems.append(String(localized: """
            \(state.app.name) has \(state.pageCount) of \(limit) pages and \(waiting) suggested pages waiting, which would \
            fill the rest: wait for the person to accept or dismiss them.
            """))
        }
    }

    // MARK: - Reading

    /// `defaultPage` (or left out), `empty`, or the id of a page in App
    /// Store Connect to copy.
    private static func start(_ value: String?, in state: MCPProductPages) throws -> ProductPageStart {
        guard let value, value.caseInsensitiveCompare("defaultPage") != .orderedSame, value.caseInsensitiveCompare("default") != .orderedSame else {
            return .defaultPage
        }
        if value.caseInsensitiveCompare("empty") == .orderedSame { return .empty }
        guard let page = state.page(value), !page.isDraft else {
            throw MCPToolError.invalidArgument(name: "startFrom", expected: String(localized: """
            defaultPage, empty, or the id of a page in App Store Connect to copy (a draft can't be copied until it's pushed)
            """))
        }
        return .copy(pageID: page.id, name: page.name)
    }

    /// `{locale: [keyword]}` (or a comma-separated string): the approved
    /// version's keywords, spelled as it has them, none another page uses.
    private mutating func readKeywords(_ object: [String: JSONValue]?, in state: MCPProductPages) throws {
        guard let object, !object.isEmpty else { return }
        guard state.defaultPage.hasApprovedVersion else {
            problems.append(String(localized: "No version of \(state.app.name) is approved yet, so pages can't choose keywords: leave keywords out."))
            return
        }
        for (code, value) in object.sorted(by: { $0.key < $1.key }) {
            guard let locale = state.locale(code) else {
                problems.append(MCPPromotionalText.localeProblem(code, in: state))
                continue
            }
            var chosen: [String] = []
            for keyword in try Self.words(value) {
                guard let approved = state.approvedKeyword(keyword, locale: locale) else {
                    let version = state.defaultPage.approvedVersionString ?? ""
                    problems.append(String(localized: """
                    “\(keyword)” isn't one of version \(version)'s keywords in \(locale): choose from keywords.\(locale).free in \
                    get_product_pages.
                    """))
                    continue
                }
                if let owner = state.keywordOwner(approved, locale: locale) {
                    problems.append(String(localized: """
                    “\(approved)” (\(locale)) leads to “\(owner.name)” already: a keyword leads to one page. Choose another, or \
                    leave it out.
                    """))
                    continue
                }
                if !chosen.contains(approved) { chosen.append(approved) }
            }
            if !chosen.isEmpty { suggestion.keywords[locale] = chosen }
        }
    }

    private static func words(_ value: JSONValue) throws -> [String] {
        if let text = value.stringValue { return ProductPageChangeBuilder.keywords(in: text) }
        guard let items = value.arrayValue?.map(\.stringValue), !items.contains(nil) else {
            throw MCPToolError.invalidArgument(name: "keywords", expected: String(localized: "an object of locale → list of keywords"))
        }
        return items.compactMap { $0?.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// `{locale: text}`: offered, Not offered, or a problem.
    private mutating func readTexts(_ object: [String: JSONValue]?, in state: MCPProductPages) throws {
        for (code, value) in (object ?? [:]).sorted(by: { $0.key < $1.key }) {
            guard let text = value.stringValue else {
                throw MCPToolError.invalidArgument(name: "promotionalText", expected: String(localized: "an object of locale → text"))
            }
            switch MCPPromotionalText.check(locale: code, text: text, in: state) {
            case let .offered(locale, checked): suggestion.promotionalTexts[locale] = checked
            case let .notOffered(locale, checked, issues): notOffered.append((locale, checked, issues))
            case .empty: break
            case let .problem(problem): problems.append(problem)
            }
        }
    }

    private mutating func readDeepLink(_ link: String?, in state: MCPProductPages) {
        guard let link else { return }
        let known = state.pages.map(\.deepLink).filter { !$0.isEmpty }
        if let problem = ProductPageDeepLinkCheck(link: link, knownLinks: known, appName: state.app.name).blockingProblem {
            problems.append(problem)
        } else {
            suggestion.deepLink = link
        }
    }

    /// The screens in order, each a name or `{screen, caption}`, or one
    /// sentence: "Weekly Reflections first, then Mood".
    private mutating func readScreens(_ value: JSONValue?) throws {
        guard let value, !value.isNull else { return }
        if let text = value.stringValue {
            suggestion.screens = text.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let items = value.arrayValue {
            var parts: [String] = []
            for item in items {
                let screen = (item.stringValue ?? item["screen"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !screen.isEmpty else {
                    throw MCPToolError.invalidArgument(name: "screens", expected: String(localized: "a list of screen names or {screen, caption} objects"))
                }
                let caption = (item["caption"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let issues = StoreTextGuidelineCheck.issues(inCaption: caption)
                if !issues.isEmpty { problems.append(String(localized: "The caption for \(screen): \(issues.assistantReason)")) }
                parts.append(caption.isEmpty ? screen : "\(screen) (“\(caption)”)")
            }
            suggestion.screens = parts.joined(separator: String(localized: ", then "))
        } else {
            throw MCPToolError.invalidArgument(name: "screens", expected: String(localized: "a list of screen names or {screen, caption} objects"))
        }
        if suggestion.screens.count > Self.screensLimit {
            problems.append(String(localized: "screens has \(suggestion.screens.count) characters; it holds \(Self.screensLimit)."))
        }
    }
}
