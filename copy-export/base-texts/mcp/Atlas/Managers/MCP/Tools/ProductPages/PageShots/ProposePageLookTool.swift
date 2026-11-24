//
//  ProposePageLookTool.swift
//  Atlas
//

import Foundation

/// `propose_page_look`: one of the three looks for a page's set (board 52,
/// A new look from Claude Design), as an Atlas template laid on the
/// default page's template or a starter. Atlas checks it field by field,
/// draws the page's first screenshot with it and returns the image; the
/// person chooses one of the three.
struct ProposePageLookTool: MCPTool {
    var studio = PageShotsStudio.shared

    static let maxName = 40
    static let maxRationale = 300
    static let previewWidth = 400

    let definition = MCPToolDefinition(
        name: "propose_page_look",
        title: "Propose a look for a product page's screenshots",
        description: """
        Sends one of three looks for a custom product page's own screenshots, when the person chose A new look from \
        Claude Design in Make Screenshots for This Page (get_page_screenshots' look.choice is claudeDesign): a name \
        ("Quiet Indigo"), a one-sentence rationale, and the template — the JSON get_template returns (any subset of its \
        fields) and/or ops on dotted paths — laid on base: default (the default page's template) or a starter. Atlas \
        checks it like an edit in the template editor (unknown fields, values out of range and fonts that can't draw a \
        language are refused), draws the page's first screenshot with it and attaches the image: look at it. A look \
        sent again with the same name takes the place of the one before. At most three; the person chooses one. The \
        default page's screenshots never change.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "page": MCPToolDefinition.string("The page's name or id, as get_page_screenshots has it."),
                "name": MCPToolDefinition.string("The look's name, e.g. Quiet Indigo."),
                "rationale": MCPToolDefinition.string("Why it suits this page's audience, in a sentence the person reads."),
                "base": MCPToolDefinition.string("default (the default page's template), or a starter from get_page_screenshots' look.starters."),
                "template": ["type": "object", "description": "Template fields, as get_template returns them."],
                "ops": ["type": "array", "items": ["type": "object"], "description": "{op: \"replace\", path, value} changes."],
                "sourceLink": MCPToolDefinition.string("Where to refine it, e.g. the Claude Design project's link."),
            ],
            required: ["appId", "page", "name", "rationale"]
        ),
        proposalKind: .screenshots
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let found: PageShotsMCPRun
        switch try await PageShotsMCPRun.find(arguments, in: context, studio: studio) {
        case let .success(run): found = run
        case let .failure(refusal): return refusal.outcome
        }
        if let refusal = refusal(found) { return .refused(refusal, target: found.target) }
        let name = try arguments.string("name").trimmingCharacters(in: .whitespacesAndNewlines)
        let rationale = try arguments.string("rationale").trimmingCharacters(in: .whitespacesAndNewlines)
        if let problem = textProblem(name: name, rationale: rationale) { return .refused(problem, target: found.target) }
        let template: ScreenshotTemplate
        do {
            let base = try base(arguments, found: found)
            template = try MCPDirectionTemplate.template(arguments, base: base, fonts: context.workspace.services.screenshots.fonts)
        } catch {
            return .refused(error.localizedDescription, target: found.target)
        }
        let candidate = try PageShotsLookCandidate(
            id: "look-" + UUID().uuidString.lowercased().prefix(8), name: name, rationale: rationale, template: template,
            link: arguments.optionalString("sourceLink"), source: context.clientName, receivedAt: .now
        )
        if let why = studio.receive(look: candidate, for: found.run.key) { return .refused(why, target: found.target) }
        let run = studio.run(found.run.key) ?? found.run
        var drawn = found.source
        drawn.lookTemplate = template
        let screens = run.plan?.screens ?? [PageShotsScreen(slot: 0, captions: [:])]
        let tight = tightPlaces(screens, source: drawn, run: run)
        var result: [String: JSONValue] = [
            "status": "received",
            "look": .string(candidate.id),
            "received": .int(run.design?.candidates.count ?? 1),
            "of": .int(PageShotsDesign.candidateCount),
            "next": .string(next(run, tight: tight)),
        ]
        if !tight.isEmpty { result["captionsThatDontFit"] = .array(tight.map(JSONValue.int)) }
        var images: [MCPToolOutcome.ImageContent] = []
        if let locale = StoreLocaleCatalog.locale(code: run.primaryLocale),
           let preview = await drawn.render(
               position: 0, of: screens, caption: screens.first?.caption(run.primaryLocale), locale: locale,
               displayType: run.displays.first ?? .iPhone, pixelWidth: Self.previewWidth
           )
        {
            images.append(MCPToolOutcome.ImageContent(data: preview.data, mimeType: "image/png"))
            result["preview"] = "The page's first screenshot with this look, in the primary language, is attached."
        }
        let line = MCPToolOutcome.LogLine(target: "\(found.target) · \(name)", outcome: .proposed)
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [line], images: images)
    }

    private func refusal(_ found: PageShotsMCPRun) -> String? {
        if let problem = found.source.problem { return problem }
        if !found.run.look.isClaudeDesign {
            return String(localized: """
            The person didn’t ask for a new look: the page’s set uses \(lookName(found.run.look)). Send looks only when \
            get_page_screenshots’ look.choice is claudeDesign.
            """)
        }
        if found.run.stage == .making {
            return String(localized: "Atlas is laying out the set the person started. Wait until it's done.")
        }
        return nil
    }

    private func lookName(_ look: PageShotsLook) -> String {
        switch look {
        case .same, .claudeDesign: String(localized: "the default page’s template")
        case let .starter(starter): String(localized: "the \(starter.title) template")
        }
    }

    private func textProblem(name: String, rationale: String) -> String? {
        if name.isEmpty { return String(localized: "Send `name`: what the person calls the look, e.g. Quiet Indigo.") }
        if name.count > Self.maxName { return String(localized: "`name` is \(name.count) characters; keep it to \(Self.maxName).") }
        if rationale.isEmpty { return String(localized: "Send `rationale`: why the look suits this page’s audience, in a sentence.") }
        if rationale.count > Self.maxRationale {
            return String(localized: "`rationale` is \(rationale.count) characters; keep it to \(Self.maxRationale).")
        }
        return nil
    }

    /// `base`: the default page's template, or a starter sized for the set.
    private func base(_ arguments: MCPToolArguments, found: PageShotsMCPRun) throws -> ScreenshotTemplate {
        let name = try arguments.optionalString("base")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "default"
        if name.isEmpty || name.caseInsensitiveCompare("default") == .orderedSame {
            guard let template = found.source.document.template else {
                throw MCPToolError.unavailable(String(localized: "The default page has no template yet."))
            }
            return template
        }
        guard let starter = TemplateStarter.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(name) == .orderedSame }) else {
            let names = (["default"] + TemplateStarter.allCases.map(\.rawValue)).formatted(.list(type: .or))
            throw MCPToolError.invalidArgument(name: "base", expected: names)
        }
        return ScreenshotTemplate.starter(starter, id: found.app.id, title: found.app.name, slotCount: max(found.source.slotCount, 1))
    }

    /// The places (1-based) whose primary caption doesn't fit this look on
    /// one of the run's devices.
    private func tightPlaces(_ screens: [PageShotsScreen], source: PageShotsSource, run: PageShotsRun) -> [Int] {
        guard let locale = StoreLocaleCatalog.locale(code: run.primaryLocale) else { return [] }
        return screens.indices.filter { place in
            guard let caption = screens[place].caption(run.primaryLocale) else { return false }
            return run.displays.contains { !source.fits(caption, position: place, of: screens, locale: locale, displayType: $0) }
        }
        .map { $0 + 1 }
    }

    private func next(_ run: PageShotsRun, tight: [Int]) -> String {
        if !tight.isEmpty {
            let places = tight.map(String.init).formatted(.list(type: .and))
            return String(localized: """
            The captions at place \(places) don’t fit this look’s caption box. Give the caption more room or a smaller \
            size, and send the look again with the same name.
            """)
        }
        let left = PageShotsDesign.candidateCount - (run.design?.candidates.count ?? 0)
        if left > 0 {
            return left == 1
                ? String(localized: "Send 1 more look, different from the others.")
                : String(localized: "Send \(left) more looks, different from this one and from each other.")
        }
        return String(localized: "Done. The person chooses one of the three in Atlas and starts Autopilot.")
    }
}
