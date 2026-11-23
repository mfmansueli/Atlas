//
//  ProposePageScreenshotsTool.swift
//  Atlas
//

import Foundation

/// `propose_page_screenshots`: the plan of a custom product page's own
/// screenshots (board 52): the angle, the default set's screens in the
/// page's order and a caption for each in the page's languages. Checked
/// like the person's captions (`PageShotsProposal`); a first plan waits
/// for the person at Plan, a plan after Ask for Changes is laid out again
/// right away. Nothing reaches App Store Connect until the person pushes.
struct ProposePageScreenshotsTool: MCPTool {
    var studio = PageShotsStudio.shared

    let definition = MCPToolDefinition(
        name: "propose_page_screenshots",
        title: "Plan a product page's screenshots",
        description: """
        Sends the plan of a custom product page's own screenshots after get_page_screenshots: `angle` (the page's story \
        in a sentence, ≤200 characters), `reason` (why this order and these words for this audience, one sentence, at most \
        \(AssistantTextLimits.why) characters; the rest in `details`, with `confidence` 1–3), `screens` in \
        the page's order [{screen, captions: {locale: {headline, subhead}}}], each `screen` one of the default set's, \
        numbered from 1, at most 10, and `languages` (the ones you think need the page's own images; the primary is \
        always among them). Every screen needs a caption in the primary language. Atlas checks each caption against App \
        Review's rules and the template's caption box on every device; one that fails is left out and listed in \
        `refused` with why, and a primary caption that fails refuses the whole plan. Each screen keeps the captions \
        Atlas has for it unless you send them again, wherever it moves (one that no longer fits its new place is left \
        out and listed), so send the other languages a few at a time with the same screens; a screen you leave out \
        goes with its captions. You can't push: the person makes the set, looks at it and puts it in Review & Push.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPToolDefinition.withLayers([
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "page": MCPToolDefinition.string("The page's name or id, as get_page_screenshots has it."),
                "angle": MCPToolDefinition.string("The page's story in a sentence, e.g. “Privacy first: the lock, then writing, then search.”"),
                "reason": MCPToolDefinition.why("Why this order and these words, for this page's audience."),
                "screens": Self.screensSchema,
                "languages": ["type": "array", "items": ["type": "string"], "description": "The languages that should get the page's own images."],
            ]),
            required: ["appId", "page", "screens"]
        ),
        proposalKind: .screenshots
    )

    private static let captionSchema: JSONValue = MCPToolDefinition.schema(
        ["headline": MCPToolDefinition.string("The headline."), "subhead": MCPToolDefinition.string("The subhead, optional.")],
        required: ["headline"]
    )

    private static let screenSchema: JSONValue = MCPToolDefinition.schema(
        [
            "screen": ["type": "integer", "description": "One of the default set's screens, from 1, as get_page_screenshots lists them."],
            "captions": ["type": "object", "additionalProperties": captionSchema, "description": "Locale → {headline, subhead}."],
        ],
        required: ["screen"]
    )

    private static let screensSchema: JSONValue = ["type": "array", "items": screenSchema, "description": "The screenshots in the page's order."]

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let found: PageShotsMCPRun
        switch try await PageShotsMCPRun.find(arguments, in: context, studio: studio) {
        case let .success(run): found = run
        case let .failure(refusal): return refusal.outcome
        }
        if let problem = found.source.problem { return .refused(problem, target: found.target) }
        if found.run.stage == .making {
            return .refused(String(localized: """
            Atlas is laying out the set the person started. Wait until it's done; then the person can ask for changes.
            """), target: found.target)
        }
        let proposal = PageShotsProposal(run: found.run, source: found.source)
        let outcome = try proposal.check(
            angle: arguments.optionalString("angle"), reason: arguments.optionalString("reason"), screens: arguments.array("screens"),
            locales: arguments.optionalStrings("languages"), client: context.clientName, layers: arguments.layers()
        )
        switch outcome {
        case let .refused(message, refused):
            var details: [String: JSONValue] = [:]
            if !refused.isEmpty { details["refused"] = .array(refused.map(\.json)) }
            return .refused(message, target: found.target, details: details)
        case let .planned(plan, refused):
            let remakes = found.run.stage == .revising || found.run.stage == .result || found.run.stage == .used
            studio.receive(plan, for: found.run.key, source: found.source)
            let run = studio.run(found.run.key) ?? found.run
            let missing = run.languages.filter { !plan.completeLocales(among: run.languages).contains($0) }
            var result: [String: JSONValue] = [
                "status": "planned",
                "plan": GetPageScreenshotsTool.planJSON(plan),
                "languagesWithEveryCaption": .array(plan.completeLocales(among: run.languages).map(JSONValue.string)),
            ]
            if !refused.isEmpty { result["refused"] = .array(refused.map(\.json)) }
            if !missing.isEmpty { result["missingLanguages"] = .array(missing.map(JSONValue.string)) }
            result["next"] = .string(next(missing: missing, refused: refused, remakes: remakes))
            let line = MCPToolOutcome.LogLine(target: found.target, outcome: .proposed)
            return MCPToolOutcome(result: .object(result), isError: false, logLines: [line])
        }
    }

    private func next(missing: [String], refused: [PageShotsProposal.Refusal], remakes: Bool) -> String {
        if !refused.isEmpty {
            return String(localized: "Fix the captions in `refused` and send them again with the same screens: the rest stay.")
        }
        if !missing.isEmpty {
            let list = missing.formatted(.list(type: .and))
            return String(localized: "Send the captions in \(list) the same way, with the same screens.")
        }
        if remakes {
            return String(localized: "Done. Atlas is laying the set out again for the person to look at.")
        }
        return String(localized: "Done. The person looks at the plan in Atlas and starts Autopilot.")
    }
}
