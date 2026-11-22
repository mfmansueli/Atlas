//
//  RequestRecaptureTool.swift
//  Atlas
//

import Foundation

/// `request_recapture`: redo only some captures (and App Preview moments)
/// instead of a whole Autopilot run, when the app changed under them
/// (Alba's Japanese phrases rewritten: 18 captures in ja on iPhone, iPhone
/// Duo and iPad, and the App Preview's moment). It waits in Screenshots for
/// the person's Accept, which opens a capture-only run; with Settings →
/// Screenshots → "Let Claude Code open capture-only runs" on it opens at
/// once. Either way get_capture_plan, next_step and report_capture then
/// work as in any run, with only those captures. It works without a saved
/// run too: the plan then comes from the captures the set uses
/// (`AutopilotRecapturePlanFromCaptures`), and only App Preview moments,
/// whose recordings went with the run, are refused.
struct RequestRecaptureTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "request_recapture",
        title: "Ask to redo some captures",
        description: """
        Asks Atlas to redo only some of the app's captures, and moments of its App Preview, without a whole \
        Autopilot run: when the app's screens changed (new texts in a language, a redesigned screen). It works even \
        when the app has no saved Autopilot run: the run is then made from the captures the set uses (list_captures: \
        their screens, devices, iPhone Duo poses and sizes), and only what has a capture can be redone; moments need \
        the run's recordings, so without one they come back in unknownMoments with momentsReason. Each item of \
        targets names a screen (its id, name or number in the plan) or a slot (from 1, as list_captures numbers \
        them), a locale, a displayType (left out: every device that captures it) and on \
        iPhone Duo a pose (left out: both); an item with only a locale is every screen in it. moments are App Preview \
        moments (screen ids) to record again. Give the reason and evidence (a file or commit) the person reads. \
        Result status queued (with requestId): Atlas shows it to the person with Accept and Decline, and once \
        accepted the run waits for you; tell the person, and nothing else to do until then. Status opened: the \
        person let you open capture-only runs; go on with get_capture_plan, then next_step after each step, which \
        asks only for these captures. Plan, Design and the captions are skipped: the set keeps its template and \
        captions, and Review & Push sends only the images that change. Nothing reaches App Store Connect until the \
        person pushes.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "targets": [
                    "type": "array",
                    "description": "The captures to redo.",
                    "items": MCPToolDefinition.schema(
                        [
                            "screen": MCPToolDefinition.string("The screen's id, name or number in the plan (get_capture_plan's screens)."),
                            "slot": ["type": "integer", "description": "Instead of screen: the set's slot, from 1, as list_captures has it."],
                            "locale": MCPToolDefinition.string("The locale, e.g. ja."),
                            "displayType": MCPToolDefinition.string("iphone, iphone_duo, ipad, mac, watch or vision_pro; leave out for every device."),
                            "pose": MCPToolDefinition.string("On iPhone Duo: open or closed; leave out for both."),
                        ],
                        required: ["locale"]
                    ),
                ],
                "moments": ["type": "array", "items": ["type": "string"], "description": "App Preview moments to record again, by screen id."],
                "reason": MCPToolDefinition.string("Why they need redoing, in a sentence the person reads, e.g. the phrases were rewritten."),
                "evidence": MCPToolDefinition.string("What shows it: a file or commit, e.g. d038b58."),
            ],
            required: ["appId", "reason"]
        ),
        changesState: true
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let (app, center) = try await MCPAutopilotSession.center(arguments, in: context)
        let target = MCPAutopilotSession.target(app)
        if let run = center.run(for: app.id), run.isRecapturing {
            return .refused(String(localized: """
            A capture-only run is open for \(run.recapture?.title ?? ""). Call get_capture_plan and next_step to capture it.
            """), target: target)
        }
        // No saved run: the plan comes from the captures the set uses.
        var fromCaptures: AutopilotRecapturePlanFromCaptures?
        if center.redoesFromCaptures(appID: app.id) {
            guard let made = try await Self.planFromCaptures(app: app, center: center, in: context) else {
                return .refused(AutopilotCenter.noCapturesRefusal(appName: app.name), target: target)
            }
            fromCaptures = made
        }
        let source = fromCaptures == nil ? center.replacedRun(for: app.id) ?? center.run(for: app.id) : nil
        guard let plan = fromCaptures?.plan ?? source?.plan else {
            return .refused(AutopilotCenter.noCapturesRefusal(appName: app.name), target: target)
        }
        let captured = fromCaptures.map { MCPRecaptureTargets.Captured(appName: app.name, targets: $0.capturedTargets) }
        let parsed = try MCPRecaptureTargets(arguments.optionalArray("targets") ?? [], plan: plan, captured: captured)
        let (moments, momentDetails) = try Self.moments(arguments.optionalStrings("moments") ?? [], in: source, appName: app.name)
        var details = momentDetails
        if !parsed.refused.isEmpty { details["refused"] = .array(parsed.refused) }
        guard !parsed.targets.isEmpty || !moments.ids.isEmpty else {
            let reasons = parsed.refused.compactMap { $0["reason"]?.stringValue }
            let reason = fromCaptures != nil && !reasons.isEmpty
                ? Self.unique(reasons).joined(separator: " ")
                : String(localized: "Nothing to redo: send targets the plan captures, or moments its App Preview has.")
            return .refused(reason, target: target, details: details)
        }
        let reason = try arguments.string("reason")
        let evidence = try arguments.optionalString("evidence")
        let request = AutopilotRecaptureRequest(
            id: center.makeRecaptureRequestID(), client: context.clientName, receivedAt: center.now(), targets: parsed.targets,
            momentIDs: moments.ids, reason: reason, evidence: evidence, fromCaptures: fromCaptures
        )
        details["captures"] = .int(parsed.targets.count)
        details["title"] = .string(request.headline)
        if fromCaptures != nil { details["fromCaptures"] = .string(Self.fromCapturesNote) }
        if center.opensCaptureRuns(), center.recaptureRefusal(appID: app.id) == nil {
            do {
                let opened = try center.openRecapture(
                    appID: app.id, targets: request.targets, momentIDs: request.momentIDs, reason: reason, evidence: evidence,
                    client: context.clientName, fromCaptures: fromCaptures
                )
                details["status"] = "opened"
                details["run"] = .string(opened.id)
                details["say"] = .string(Self.openedSay)
                return MCPToolOutcome(result: .object(details), isError: false, logLines: [.init(target: target, outcome: .proposed)])
            } catch {
                details["notOpened"] = .string(error.localizedDescription)
            }
        }
        center.queueRecapture(request, appID: app.id)
        details["status"] = "queued"
        details["requestId"] = .string(request.id)
        details["say"] = .string(Self.queuedSay(waitsFor: center.recaptureRefusal(appID: app.id)))
        return MCPToolOutcome(result: .object(details), isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    /// The plan made from the set's captures, when the app has no saved
    /// run: its open plan's steps and setup and what update_capture_plan
    /// sent for the next plan go in. Nil when the set has no captures.
    static func planFromCaptures(app: StoreApp, center: AutopilotCenter, in context: MCPToolContext) async throws -> AutopilotRecapturePlanFromCaptures? {
        let draft = try await MCPScreenshotsDraft.load(app: app.id, in: context.workspace)
        let version = await (try? MCPListingDraft.load(app: app.id, in: context.workspace))?.listing.version.versionString ?? ""
        let open = center.run(for: app.id).flatMap { $0.stage == .plan ? $0.plan : nil }
        return AutopilotRecapturePlanFromCaptures(
            document: draft.document, primaryLocale: draft.primary.code, versionString: version, proposals: center.planProposals(for: app.id),
            openPlan: open
        )
    }

    /// The moments `source`'s App Preview has, and the details that say
    /// which it hasn't. Without a saved run none can be recorded again:
    /// they're refused, the captures aren't.
    private static func moments(
        _ asked: [String], in source: AutopilotRun?, appName: String
    ) -> (moments: (ids: [String], unknown: [String]), details: [String: JSONValue]) {
        let moments = source.map { MCPRecaptureTargets.moments(asked, in: $0) } ?? (ids: [], unknown: asked)
        var details: [String: JSONValue] = [:]
        guard !moments.unknown.isEmpty else { return (moments, details) }
        details["unknownMoments"] = .array(moments.unknown.map(JSONValue.string))
        details["moments"] = .array((source?.pickableMoments ?? []).map { .string($0.screenID) })
        if source == nil { details["momentsReason"] = .string(noMomentsReason(appName: appName)) }
        return (moments, details)
    }

    /// Why moments can't be recorded again without a saved run.
    static func noMomentsReason(appName: String) -> String {
        String(localized: """
        \(appName) has no saved Autopilot run, so its App Preview’s recordings and moments can’t be recorded again; the \
        captures are asked for without them. To make the App Preview again, the person runs Autopilot with it.
        """)
    }

    static let fromCapturesNote = """
    No Autopilot run was saved for this app: the capture-only run is made from the captures the set uses (list_captures), \
    with their screens, devices, iPhone Duo poses and sizes. Match each capture's previousPixelSize in get_capture_plan.
    """

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }

    static let openedSay = """
    The capture-only run is open. Call get_capture_plan, build the app, then call next_step after each step: it asks only \
    for these captures (and moments), and report_capture takes them as in any run.
    """

    static func queuedSay(waitsFor refusal: String?) -> String {
        let lead = """
        Atlas shows it to the person in Screenshots with Accept and Decline. Once they accept, a capture-only run waits \
        for you: get_capture_plan, then next_step. Tell the person; nothing else to do until then.
        """
        guard let refusal else { return lead }
        return lead + " " + String(localized: "Before it can open: \(refusal)")
    }
}
