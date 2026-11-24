//
//  RequestPageRecaptureTool.swift
//  Atlas
//

import Foundation

/// `request_page_recapture`: capture again some of the default set's
/// screens for a custom product page, without the person turning on
/// Capture Screens Again (or pressing Make Screenshots for This Page)
/// first. It waits in Screenshots for Accept, or opens at once with
/// Settings → Screenshots → "Let Claude Code open capture-only runs" on;
/// then get_page_screenshots has the upload link and report_page_capture
/// names each PNG. At most three screens a page.
struct RequestPageRecaptureTool: MCPTool {
    var studio = PageShotsStudio.shared
    var store = ProductPagesStore.shared
    var analytics = AnalyticsStore.shared

    let definition = MCPToolDefinition(
        name: "request_page_recapture",
        title: "Ask to capture a product page's screens again",
        description: """
        Asks Atlas to let you capture again some of the default set's screens for a custom product page (its screens \
        should show something else for that page's audience), without the person turning on Capture Screens Again \
        first: the page, the screens (numbers from 1, as get_page_screenshots lists them; at most three a page), the \
        locale and displayType (iphone or ipad) the app runs in, and the reason and evidence the person reads. \
        Status queued (with requestId): the person accepts or declines it in Atlas; tell them, nothing else to do \
        until then. Status opened: get_page_screenshots now has recapture with the upload link; capture those \
        screens and name each PNG with report_page_capture. The default page's captures never change, and nothing \
        reaches App Store Connect until the person pushes.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "page": MCPToolDefinition.string("The page's name or id, from get_product_pages."),
                "screens": ["type": "array", "items": ["type": "integer"], "description": "The default set's screens, from 1; at most three."],
                "locale": MCPToolDefinition.string("The locale the app runs in, e.g. de-DE."),
                "displayType": MCPToolDefinition.string("iphone or ipad; iphone when left out."),
                "reason": MCPToolDefinition.string("Why these screens should show something else for this page."),
                "evidence": MCPToolDefinition.string("What shows it: a file or commit."),
            ],
            required: ["appId", "page", "screens", "locale", "reason"]
        ),
        changesState: true
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let (app, center) = try await MCPAutopilotSession.center(arguments, in: context)
        let name = try arguments.string("page").trimmingCharacters(in: .whitespacesAndNewlines)
        let target = "\(app.name) · \(name) · screenshots"
        let pages = try await MCPProductPages.load(app: app, workspace: context.workspace, store: store, analytics: analytics)
        guard let page = pages.page(name) ?? pages.pages.first(where: { ProductPageBrief.key($0.name) == ProductPageBrief.key(name) }) else {
            return .refused(String(localized: "\(app.name) has no product page “\(name)”. Read get_product_pages for its pages."), target: target)
        }
        let source = try await PageShotsSource.load(app: app, services: context.workspace.services.screenshots)
        if let problem = source.problem { return .refused(problem, target: target) }
        let checked = try check(arguments, page: page, source: source)
        let request: PageRecaptureTarget
        switch checked {
        case let .success(value): request = value
        case let .failure(refusal): return .refused(refusal.message, target: target)
        }
        let reason = try arguments.string("reason")
        let key = PageShotsRun.Key(appID: app.id, pageName: page.name)
        if let run = studio.run(key), run.stage != .used, let recapture = run.recapture {
            // The person turned it on already, or accepted before.
            let slots = Set(recapture.slots).union(request.slots)
            guard slots.count <= PageShotsRecapture.maxScreens else { return .refused(Self.tooMany(recapture.slots), target: target) }
            studio.update(key) { run in
                run.recapture?.requested = request
                run.recapture?.requestReason = reason
            }
            return opened(target: target, status: "on")
        }
        if center.opensCaptureRuns() {
            let key = studio.openRecapture(request, reason: reason, app: app, source: source)
            await studio.makeSimulator(for: request, key: key, simulators: context.simulators)
            return opened(target: target, status: "opened")
        }
        let queued = try center.queueRecapture(AutopilotRecaptureRequest(
            id: center.makeRecaptureRequestID(), client: context.clientName, receivedAt: center.now(), page: request,
            reason: reason, evidence: arguments.optionalString("evidence")
        ), appID: app.id)
        let result: JSONValue = [
            "status": "queued", "requestId": .string(queued.id), "title": .string(queued.headline),
            "say": "Atlas shows it to the person in Screenshots with Accept and Decline. Tell them; nothing else to do until then.",
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    private struct Refusal: Error {
        var message: String
    }

    /// The screens, language and device, as the page's set can have them.
    private func check(_ arguments: MCPToolArguments, page: ProductPage, source: PageShotsSource) throws -> Result<PageRecaptureTarget, Refusal> {
        let numbers = try arguments.array("screens").compactMap(\.intValue)
        var seen: Set<Int> = []
        let slots = numbers.map { $0 - 1 }.filter { seen.insert($0).inserted }
        guard !slots.isEmpty, slots.allSatisfy((0..<source.slotCount).contains) else {
            return .failure(Refusal(message: String(localized: "Send screens from 1 to \(source.slotCount), as get_page_screenshots lists them.")))
        }
        guard slots.count <= PageShotsRecapture.maxScreens else { return .failure(Refusal(message: Self.tooMany([]))) }
        let languages = source.document.scope.orderedLocales(in: StoreLocaleCatalog.all.map(\.code))
        guard let locale = try StoreLocaleCatalog.resolve(arguments.string("locale")).locale, languages.contains(locale.code) else {
            return .failure(Refusal(message: String(localized: "Send one of the page’s languages: \(languages.joined(separator: ", ")).")))
        }
        let display = try arguments.optionalString("displayType").map { ScreenshotDisplayType(mcpValue: $0) } ?? .iPhone
        guard let display, source.displays.contains(display) else {
            let devices = source.displays.map(\.mcpValue).formatted(.list(type: .or))
            return .failure(Refusal(message: String(localized: "A page’s set is made on \(devices).")))
        }
        return .success(PageRecaptureTarget(pageID: page.id, pageName: page.name, slots: slots.sorted(), locale: locale.code, displayType: display))
    }

    private func opened(target: String, status: String) -> MCPToolOutcome {
        let result: JSONValue = [
            "status": .string(status),
            "say": """
            Capture Screens Again is on for the page. Read get_page_screenshots: its recapture has the upload link and \
            the screens asked for. Capture them, upload each PNG, and name it with report_page_capture.
            """,
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    private static func tooMany(_ captured: [Int]) -> String {
        guard !captured.isEmpty else {
            return String(localized: "A page captures at most \(PageShotsRecapture.maxScreens) screens again.")
        }
        let numbers = captured.map { String($0 + 1) }.formatted(.list(type: .and))
        return String(localized: """
        Screens \(numbers) are captured again already; a page captures at most \(PageShotsRecapture.maxScreens) again. \
        Ask for one of those again instead.
        """)
    }
}
