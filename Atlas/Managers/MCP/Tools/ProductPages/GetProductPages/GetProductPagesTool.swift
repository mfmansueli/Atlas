//
//  GetProductPagesTool.swift
//  Atlas
//

import Foundation

/// `get_product_pages`: an app's default product page and its custom ones
/// as the Product Pages section shows them, with what an assistant needs to
/// suggest a page or a text: the keywords still free in each language, each
/// page's numbers against the default page's, the suggestions waiting or
/// dismissed, what's queued in Review & Push, and how many pages are left.
struct GetProductPagesTool: MCPTool {
    var store = ProductPagesStore.shared
    var analytics = AnalyticsStore.shared

    /// Past this many pages, the list leaves out their texts; `pageId`
    /// reads one page whole.
    static let pagesWithTexts = 20

    let definition = MCPToolDefinition(
        name: "get_product_pages",
        title: "Get custom product pages",
        description: """
        Reads an app's custom product pages as Atlas's Custom Product Pages section shows them. `defaultPage` is the page every \
        custom one is compared with and starts from: the version it starts from, the last approved version (whose \
        keywords pages choose), its promotional text per language and its numbers. `keywords` has, per language, the \
        approved version's keywords still `free` and the ones a page uses (`usedBy`: keyword → page name): a keyword \
        leads to one page. `pages` are App Store Connect's pages and the drafts made in Atlas (state `draft`, not in App \
        Store Connect until the person pushes): id, name, url, visible, state (PREPARE_FOR_SUBMISSION, \
        WAITING_FOR_REVIEW, IN_REVIEW, APPROVED, REJECTED…), `newVersion` when a version after the approved one is being \
        prepared or reviewed, deepLink, `languages` with their own promotional text, keywords and screenshots \
        (`textFromDefault` when only the text is the default page's), `showsDefaultIn` the languages with nothing of \
        their own, `numbers` for the last 28 days (impressions, pageViews, downloads, downloadRate, and `vsDefault`: \
        above or below by points, aboutTheSame, or tooFewToCompare under 200 page views: never quote a rate then; \
        `arrivals`, where the page's link is used: campaign tokens and referring apps or sites, most page views first), \
        `queued` (changes waiting in Review & Push, not pushed), `takesTexts` (false with `why`; `newVersionNote` \
        for an approved page), and `brief`: who an accepted suggestion's page is for and the screenshots it asked for \
        (`screenshotsAdded` stays false until the page has its own in App Store Connect: the person makes them with Make \
        Screenshots for This Page, which asks you to plan them with get_page_screenshots). `suggestions` \
        are the pages and promotional texts suggested over MCP with their status \
        (open, notOffered: stopped by App Review's rules, dismissed: don't suggest them again) and who sent them (`by`). \
        `pageLimit` is pages of 70 (drafts, hidden and rejected ones count) and the room left with the suggestions \
        waiting. `textRules` are the rules texts follow, and `next` what to do. `pageId` reads one page with its texts \
        when the list leaves them out. Read-only. Follow with propose_product_page or propose_product_page_texts.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "pageId": MCPToolDefinition.string("Only this page (an id from pages), with its texts. Leave it out for every page."),
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let state = try await MCPProductPages.load(app: app, workspace: context.workspace, store: store, analytics: analytics)
        var pages = state.pages
        let pageID = try arguments.optionalString("pageId")
        if let pageID {
            guard let page = state.page(pageID) else {
                throw MCPToolError.notFound(String(localized: "\(app.name) has no product page “\(pageID)”. Use the ids get_product_pages lists."))
            }
            pages = [page]
        }
        let withTexts = pageID != nil || pages.count <= Self.pagesWithTexts
        var result: [String: JSONValue] = [
            "appId": .string(app.id),
            "app": .string(app.name),
            "primaryLanguage": .string(state.primaryLocale),
            "pageLimit": state.limitJSON,
            "limits": ["promotionalText": .int(ProductPageField.promotionalTextLimit), "pages": .int(ProductPagesSnapshot.limit)],
            "defaultPage": Self.defaultPageJSON(state),
            "keywords": Self.keywordsJSON(state),
            "pages": .array(pages.map { .object(Self.pageJSON($0, in: state, withTexts: withTexts)) }),
            "suggestions": Self.suggestionsJSON(state, pageID: pageID),
            "textRules": ProductPageTextRules.json,
            "next": .string(Self.next(state)),
        ]
        if let numbers = state.numbers {
            // An app with fewer days of numbers says so, as Analytics does.
            var period = AnalyticsPeriod(ending: numbers.through, length: ProductPageNumbers.days)
            if let first = analytics.archive(for: app.id).firstDay, first > period.first, first <= period.last { period.first = first }
            result["numbersPeriod"] = AnalyticsMCPJSON.period(period)
        } else {
            result["numbersNote"] = .string(String(localized: """
            Atlas has no product page numbers for \(app.name) on this Mac: Analytics is off, its reports haven't come, or \
            Apple's Detailed reports have no product pages yet.
            """))
        }
        if !withTexts {
            result["textsLeftOut"] = .string(String(localized: "Pages' texts are left out past \(Self.pagesWithTexts) pages: pass pageId to read one."))
        }
        if state.archive.keyCannotChange { result["keyCannotChange"] = true }
        return .read(.object(result), target: "\(app.name) · Custom Product Pages")
    }

    /// The default page: its versions, its text per language, its numbers.
    static func defaultPageJSON(_ state: MCPProductPages) -> JSONValue {
        let page = state.defaultPage
        var object: [String: JSONValue] = [
            "name": .string(ProductPageNumbers.defaultPageName),
            "promotionalText": .object(Dictionary(uniqueKeysWithValues: page.languages.map { ($0.locale, JSONValue.string($0.promotionalText)) })),
        ]
        if let version = page.versionString { object["startsFromVersion"] = .string(version) }
        object["approvedVersion"] = page.approvedVersionString.map(JSONValue.string) ?? .null
        if let numbers = state.defaultNumbers { object["numbers"] = numbersJSON(numbers, reference: nil) }
        return .object(object)
    }

    /// Per language: the approved keywords no page uses, and the page each
    /// other one leads to.
    static func keywordsJSON(_ state: MCPProductPages) -> JSONValue {
        var object: [String: JSONValue] = [:]
        for language in state.defaultPage.languages where !language.approvedKeywords.isEmpty {
            var free: [JSONValue] = []
            var used: [String: JSONValue] = [:]
            for keyword in language.approvedKeywords {
                if let owner = state.keywordOwner(keyword, locale: language.locale) {
                    used[keyword] = .string(owner.name)
                } else {
                    free.append(.string(keyword))
                }
            }
            object[language.locale] = ["free": .array(free), "usedBy": .object(used)]
        }
        return .object(object)
    }

    /// What to do next, from where the app is.
    static func next(_ state: MCPProductPages) -> String {
        var parts: [String] = []
        if state.archive.keyCannotChange {
            parts.append(String(localized: """
            The API key can read pages but not change them: suggestions wouldn't show. Tell the person their key needs the \
            Admin, App Manager or Marketing role.
            """))
        }
        if state.pageCount >= ProductPagesSnapshot.limit {
            parts.append(String(localized: """
            \(state.app.name) has \(ProductPagesSnapshot.limit) of \(ProductPagesSnapshot.limit) pages, the most Apple allows \
            (hidden and rejected ones count): propose_product_page is refused until the person deletes one.
            """))
        }
        if !state.defaultPage.hasApprovedVersion {
            parts.append(String(localized: "No version is approved yet, so pages can't choose keywords: suggest them without."))
        }
        if state.hasPageNumbers {
            parts.append(String(localized: """
            Compare the pages with get_analytics_breakdown by productPage, and look for new audiences by source, language \
            and territory.
            """))
        } else {
            parts.append(String(localized: """
            No custom page has numbers yet: look for audiences in get_analytics_breakdown by source (search, or links from \
            other apps and websites), by language and by territory (large markets whose rates are worse than average).
            """))
        }
        parts.append(String(localized: """
        Suggest a page with propose_product_page: who it's for, its own evidence Atlas can show (those numbers, get_reviews, \
        the approved keywords), keywords from keywords.<locale>.free that its audience searches (search results show the \
        page's first three screenshots, not its text), promotional text in every language and the screens it leads with. \
        Write promotional text for a page's languages with propose_product_page_texts. Don't suggest a dismissed suggestion \
        again; send one of yours that's open again under its name to improve it. The person accepts, pushes and submits; \
        you can't push, submit or make a page visible.
        """))
        return parts.joined(separator: " ")
    }
}
