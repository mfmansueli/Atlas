//
//  GetPageScreenshotsTool.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// `get_page_screenshots`: what a custom product page's screenshot run
/// (board 52, Make Screenshots for This Page) is made from: the page (who
/// it's for, its brief, keywords and promotional text), the default set's
/// screens with their captions, the template, the page's languages and
/// devices, and the plan so far with what the person asked to change. The
/// screens' captures come with it, in order.
struct GetPageScreenshotsTool: MCPTool {
    var studio = PageShotsStudio.shared
    var store = ProductPagesStore.shared
    var analytics = AnalyticsStore.shared
    /// Attaches the screens' captures; tests skip them.
    var attachesCaptures = true

    static let captureWidth = 320

    let definition = MCPToolDefinition(
        name: "get_page_screenshots",
        title: "Get a product page's screenshot run",
        description: """
        Reads a custom product page's screenshot run in Atlas (Make Screenshots for This Page): who the page is for \
        (`page.audience`, the brief, keywords and promotional text), the default set's screens (`screens`, numbered \
        from 1, with their captions in the primary language and their captures attached in order), the template the \
        set is laid out with, the page's languages (primary first) and devices, and the run: its stage, the plan so far \
        and `changeRequest`, what the person asked to change. Plan the page's own set from it and send it with \
        propose_page_screenshots: the screens in the order that tells this page's story and a caption for each in every \
        language. The default page's screenshots never change.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "page": MCPToolDefinition.string("The page's name or id, from the prompt or get_product_pages."),
            ],
            required: ["appId", "page"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let found: PageShotsMCPRun
        switch try await PageShotsMCPRun.find(arguments, in: context, studio: studio) {
        case let .success(run): found = run
        case let .failure(refusal): return refusal.outcome
        }
        let run = found.run
        let source = found.source
        if let problem = source.problem { return .refused(problem, target: found.target) }
        let pages = try? await MCPProductPages.load(app: found.app, workspace: context.workspace, store: store, analytics: analytics)
        var result: [String: JSONValue] = [
            "appId": .string(found.app.id),
            "page": pageJSON(run, pages: pages),
            "screens": .array((0..<source.slotCount).map { screenJSON($0, source: source, primary: run.primaryLocale) }),
            "template": templateJSON(source),
            "languages": .array(run.languages.map(JSONValue.string)),
            "primaryLanguage": .string(run.primaryLocale),
            "devices": .array(run.displays.map { .string($0.title) }),
            "run": runJSON(run),
            "rules": .array(Self.rules.map(JSONValue.string)),
            "next": .string(next(run)),
        ]
        if !attachesCaptures { result["capturesAttached"] = false }
        var images: [MCPToolOutcome.ImageContent] = []
        if attachesCaptures {
            for slot in 0..<source.slotCount {
                let screen = PageShotsScreen(slot: slot, captions: [:])
                guard let capture = source.capture(of: screen, locale: run.primaryLocale, displayType: run.displays.first ?? .iPhone),
                      let image = await source.services.captureImage(capture.capture, for: found.app, pixelWidth: Self.captureWidth),
                      let data = ScreenshotPNG.data(image) else { continue }
                images.append(MCPToolOutcome.ImageContent(data: data, mimeType: "image/png"))
            }
        }
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: found.target, outcome: .read)], images: images)
    }

    static let rules = [
        String(localized: """
        Use the default set's screens, each once and at most 10, in the order that tells this page's story: its first \
        three show in search results, so open with what this page's audience came for.
        """),
        String(localized: """
        Write each caption for this audience, short and concrete, about what the screen shows. Atlas checks it fits the \
        template's caption box on every device and refuses one that doesn't, with how many lines it needs.
        """),
        String(localized: """
        Every screen needs a caption in the primary language. Write the others in every language the page is in; a \
        language without all its captions keeps the default page's screenshots.
        """),
        String(localized: """
        App Review's metadata rules apply to captions: no prices, “free” or trial lengths, no other platforms or apps, \
        no unverifiable claims such as “#1”, no beta or “coming soon”, no placeholder text.
        """),
    ]

    private func pageJSON(_ run: PageShotsRun, pages: MCPProductPages?) -> JSONValue {
        var page: [String: JSONValue] = [
            "id": .string(run.pageID),
            "name": .string(run.pageName),
            "isDraft": .bool(ProductPageDraft.isDraftID(run.pageID)),
        ]
        if !run.note.isEmpty { page["audience"] = .string(run.note) }
        if let pages {
            if let brief = pages.archive.briefs?[ProductPageBrief.key(run.pageName)] {
                page["brief"] = ["audience": .string(brief.audience), "screens": .string(brief.screens), "source": .string(brief.source)]
            }
            if let shown = pages.page(run.pageID) ?? pages.pages.first(where: { ProductPageBrief.key($0.name) == run.key.page }) {
                var keywords: [String: JSONValue] = [:]
                var texts: [String: JSONValue] = [:]
                for locale in run.languages {
                    let words = pages.keywords(of: shown, locale: locale)
                    if !words.isEmpty { keywords[locale] = .array(words.map(JSONValue.string)) }
                    let text = pages.text(of: shown, locale: locale)
                    if !text.isEmpty { texts[locale] = .string(text) }
                }
                if !keywords.isEmpty { page["keywords"] = .object(keywords) }
                if !texts.isEmpty { page["promotionalText"] = .object(texts) }
            }
        }
        return .object(page)
    }

    private func screenJSON(_ slot: Int, source: PageShotsSource, primary: String) -> JSONValue {
        var screen: [String: JSONValue] = ["screen": .int(slot + 1), "name": .string(source.slotName(slot))]
        if let caption = source.caption(locale: primary, slot: slot) {
            var json: [String: JSONValue] = ["headline": .string(caption.headline)]
            if let subhead = caption.visibleSubhead { json["subhead"] = .string(subhead) }
            screen["defaultCaption"] = .object(json)
        }
        return .object(screen)
    }

    private func templateJSON(_ source: PageShotsSource) -> JSONValue {
        guard let template = source.template else { return .null }
        return [
            "name": .string(template.name),
            "designs": .int(template.slots.count),
            "note": .string(String(localized: """
            The default page's look: the screenshot at place n takes the template's design for place n (the last one \
            past its end), so a set that runs across screenshots still does.
            """)),
        ]
    }

    private func runJSON(_ run: PageShotsRun) -> JSONValue {
        var json: [String: JSONValue] = [
            "stage": .string(run.stage.rawValue),
            "languagesChosen": .array(run.locales.map(JSONValue.string)),
        ]
        if let change = run.changeRequest { json["changeRequest"] = .string(change) }
        if let plan = run.plan { json["plan"] = Self.planJSON(plan) }
        return .object(json)
    }

    static func planJSON(_ plan: PageShotsPlan) -> JSONValue {
        [
            "angle": .string(plan.angle),
            "reason": .string(plan.reason),
            "languages": .array(plan.locales.map(JSONValue.string)),
            "screens": .array(plan.screens.map { screen in
                var captions: [String: JSONValue] = [:]
                for (locale, caption) in screen.captions {
                    var json: [String: JSONValue] = ["headline": .string(caption.headline)]
                    if let subhead = caption.subhead { json["subhead"] = .string(subhead) }
                    captions[locale] = .object(json)
                }
                return ["screen": .int(screen.slot + 1), "captions": .object(captions)]
            }),
        ]
    }

    private func next(_ run: PageShotsRun) -> String {
        if let change = run.changeRequest, run.stage == .revising {
            return String(localized: """
            The person asked: “\(change)”. Change only that, and send the whole plan again with propose_page_screenshots; \
            Atlas lays the set out again.
            """)
        }
        if let plan = run.plan {
            let missing = run.languages.filter { !plan.completeLocales(among: run.languages).contains($0) }
            if !missing.isEmpty {
                let list = missing.formatted(.list(type: .and))
                return String(localized: "Send the captions in \(list) with propose_page_screenshots, with the same screens.")
            }
            return String(localized: "The plan is in Atlas. The person looks at it and starts Autopilot.")
        }
        return String(localized: """
        Plan the set and send it with propose_page_screenshots: the angle, the screens in order, and a caption for each \
        in every language.
        """)
    }
}
