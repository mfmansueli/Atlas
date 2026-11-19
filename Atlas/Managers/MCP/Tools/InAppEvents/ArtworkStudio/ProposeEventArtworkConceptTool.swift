//
//  ProposeEventArtworkConceptTool.swift
//  Atlas
//

import Foundation

/// `propose_event_artwork_concept`: one concept for the event artwork the
/// person asked for in Atlas (board 47): its card and details image as a
/// pair. Atlas renders the pages (in each language when the name is drawn
/// in, and as loops with motion), checks them under the App Store's text,
/// and shows them in the sheet's Making and Choose steps. Nothing is
/// queued until the person uses one.
struct ProposeEventArtworkConceptTool: MCPTool {
    var studio = EventArtworkStudio.shared
    /// Where the files are kept; tests use their own folder.
    var directory = InAppEventArtworkFiles.directory
    /// How many frames a loop gets; nil is the whole 20 seconds.
    var loopFrames: Int?
    /// The pages render_event_artwork made files from, so a concept sent by
    /// a render's file id keeps its page.
    var pages = EventArtworkRenderedPages.shared

    let definition = MCPToolDefinition(
        name: "propose_event_artwork_concept",
        title: "Propose an event artwork concept",
        description: """
        Sends one concept for the In-App Event artwork the person asked for with Make the Artwork in Atlas (read it with \
        get_event_artwork_brief first). A concept is the card (16:9) and the details image (9:16) from one composition, \
        or only the details image when the brief extends the card. Give each as a full HTML page (`cardHtml`, \
        `detailsHtml`), or as a file render_event_artwork made or one sent to the upload link (`cardFileId`, \
        `detailsFileId`): a render's file keeps its page. Atlas renders the pages at 3840 × 2160 and 2160 × 3840 (with \
        {{eventName}} drawn in each language when the brief has wordsInArt, and as a 20-second loop when it has motion), \
        checks them under the event's text and shows them to the person. `name` is two or three words, `why` one \
        sentence on the idea for the person, `pick` true on the one you'd choose. When the brief has a revision, send \
        only that concept again with `replaces`. Refused when a render breaks Apple's rules: fix it and send it again. \
        Nothing is queued or pushed: the person chooses and uses one in Atlas.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "eventId": MCPToolDefinition.string("The event's id."),
                "name": MCPToolDefinition.string("The concept's name, two or three words, e.g. Snowfall Path."),
                "why": MCPToolDefinition.string("One sentence for the person: the idea, and why it reads at card size."),
                "pick": ["type": "boolean", "description": "True on the concept you'd choose. Default false."],
                "cardHtml": MCPToolDefinition.string("The card as a full HTML page, 16:9."),
                "detailsHtml": MCPToolDefinition.string("The details image as a full HTML page, 9:16."),
                "cardFileId": MCPToolDefinition.string("The card as a file from render_event_artwork or the upload link, instead of cardHtml."),
                "detailsFileId": MCPToolDefinition.string("The details image as a file from render_event_artwork or the upload link, instead of detailsHtml."),
                "replaces": MCPToolDefinition.string("The conceptId being redrawn or given motion, from the brief's revision or addMotion."),
            ],
            required: ["appId", "eventId", "name", "why"]
        ),
        proposalKind: .artwork
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let eventID = try arguments.string("eventId")
        let name = try arguments.string("name").trimmingCharacters(in: .whitespacesAndNewlines)
        let target = "\(app.name) · \(eventID) · concept “\(name)”"
        guard context.allows(.screenshots) else { return .refused(MCPProposalKind.screenshots.refusal, target: target) }
        guard let run = studio.run(appID: app.id, eventID: eventID) else { return .refused(GetEventArtworkBriefTool.noRun, target: target) }
        let replaces = try arguments.optionalString("replaces")
        if let reason = Self.refusal(run, replaces: replaces, name: name) { return .refused(reason, target: target) }
        let event = try await RenderEventArtworkTool.event(eventID, of: app, in: context)
        let made: Made
        switch try await make(arguments, run: run, event: event, app: app) {
        case let .made(result): made = result
        case let .refused(reason, details): return .refused(reason, target: target, details: details)
        }
        let why = try arguments.string("why").trimmingCharacters(in: .whitespacesAndNewlines)
        let isPick = try arguments.optionalBool("pick") ?? false
        let concept = EventArtworkConcept(
            id: replaces ?? run.nextConceptID, name: name, why: why, isPick: isPick, client: context.clientName, pages: made.pages,
            stills: made.stills, videos: made.videos, checks: EventArtworkConceptChecks.make(made.reports, wordsInArt: run.wordsInArt),
            arrivedAt: .now
        )
        guard let updated = studio.add(concept, to: run.key, replacing: replaces) else { return .refused(GetEventArtworkBriefTool.noRun, target: target) }
        // Its files say which concept they are, for get_in_app_events.
        InAppEventArtworkFiles.markConcept(
            (concept.stills + concept.videos).map(\.fileID), conceptID: concept.id, title: name, appID: app.id, in: directory
        )
        let warnings = concept.checks.filter { !$0.isOK }.map { JSONValue.string("\($0.title): \($0.detail)") }
        let left = max(0, updated.expectedCount - updated.designedCount)
        let motionLeft = updated.animatingIDs?.count ?? 0
        let done = motionLeft == 0 && (replaces != nil || left == 0)
        var result: [String: JSONValue] = [
            "status": "received",
            "conceptId": .string(replaces ?? concept.id),
            "ready": .int(updated.designedCount),
            "of": .int(updated.expectedCount),
            "warnings": .array(warnings),
            "then": .string(
                done ? "Done: the person chooses in Atlas. Finish without pushing anything."
                    : motionLeft > 0 ? "Give the next concept its motion (\(motionLeft) left), with replaces." : "Send the next concept (\(left) left)."
            ),
        ]
        // Runs drawn at the same time read their briefs before the others
        // sent anything: what they've sent since comes here.
        if !done, motionLeft == 0, let others = EventArtworkOtherEvents.json(studio.runs(for: app.id), except: eventID) {
            result["otherEvents"] = others
            result["then"] = .string("Send the next concept (\(left) left), a different idea from otherEvents' too.")
        }
        return MCPToolOutcome(
            result: .object(result),
            isError: false,
            logLines: [.init(target: target, outcome: .proposed)]
        )
    }

    /// Why this concept isn't taken now; nil when it is.
    static func refusal(_ run: EventArtworkRun, replaces: String?, name: String) -> String? {
        guard !name.isEmpty else { return "Give the concept a name of two or three words." }
        guard run.step == .making else {
            return "The person isn’t waiting for concepts any more (the run is at \(run.step.title)). Finish."
        }
        if run.isAnimating {
            let ids = run.animatingIDs ?? []
            guard let replaces, ids.contains(replaces) else {
                return """
                The person asked for motion on concepts that are already drawn: send each with replaces, one of \
                \(ids.joined(separator: ", ")) from get_event_artwork_brief's addMotion.
                """
            }
            return nil
        }
        if let replaces {
            guard run.concepts.contains(where: { $0.id == replaces }) else {
                return "There’s no concept “\(replaces)”: use the conceptId from get_event_artwork_brief's revision."
            }
            return nil
        }
        if run.revisingID != nil { return "The person asked for a change to one concept: send it with replaces from the brief's revision." }
        return run.isComplete ? "Every concept is in. Finish." : nil
    }

    /// A concept's rendered files and their checks.
    struct Made {
        var stills: [EventArtworkImage] = []
        var videos: [EventArtworkImage] = []
        var pages: [InAppEventMedia.Kind: String] = [:]
        var reports: [InAppEventArtworkReport] = []
    }

    enum Making {
        case made(Made)
        case refused(String, details: [String: JSONValue] = [:])
    }

    /// Renders or reads each kind the run makes, and checks them; refused
    /// when one is missing or breaks Apple's rules.
    func make(_ arguments: MCPToolArguments, run: EventArtworkRun, event: InAppEvent, app: StoreApp) async throws -> Making {
        var made = Made()
        for kind in run.style.kinds {
            switch try source(arguments, kind: kind, run: run) {
            case .missing:
                return .refused("Give the \(kind.name) as \(kind.mcpValue)Html or \(kind.mcpValue)FileId.")
            case let .file(id):
                if let page = pages.page(for: id) { made.pages[kind] = page }
                guard let report = await InAppEventArtworkReport.make(fileID: id, appID: app.id, kind: kind, language: run.primaryLocale, in: directory)
                else { return .refused(ProposeEventArtworkTool.missingFile(id)) }
                made.reports.append(report)
                let image = EventArtworkImage(kind: kind, fileID: id, path: report.url.path(percentEncoded: false), isVideo: report.file.isVideo)
                if report.file.isVideo { made.videos.append(image) } else { made.stills.append(image) }
            case let .html(html):
                made.pages[kind] = html
                let rendered = try await render(html, kind: kind, run: run, event: event, app: app)
                made.stills += rendered.stills
                made.videos += rendered.videos
                if let primary = rendered.stills.first(where: { $0.locale == nil || $0.locale == run.primaryLocale }),
                   let report = await InAppEventArtworkReport.make(
                       fileID: primary.fileID, appID: app.id, kind: kind, language: run.primaryLocale, in: directory
                   )
                {
                    made.reports.append(report)
                }
            }
        }
        let refusals = made.reports.flatMap { report in report.checks.filter(\.isRefusal).map { "\(report.kind.title): \($0.text)" } }
        guard refusals.isEmpty else {
            return .refused("Apple wouldn’t take this concept as it is.", details: ["refusals": .array(refusals.map(JSONValue.string))])
        }
        return .made(made)
    }

    enum Source {
        case html(String)
        case file(String)
        case missing
    }

    static func source(_ arguments: MCPToolArguments, kind: InAppEventMedia.Kind) throws -> Source {
        if let html = try arguments.optionalString("\(kind.mcpValue)Html"), !html.isEmpty { return .html(html) }
        if let id = try arguments.optionalString("\(kind.mcpValue)FileId"), !id.isEmpty { return .file(id) }
        return .missing
    }

    /// The kind's source, with a render's file taken back to its page when
    /// the run needs the page drawn again: the name in each language, or
    /// the moving version.
    func source(_ arguments: MCPToolArguments, kind: InAppEventMedia.Kind, run: EventArtworkRun) throws -> Source {
        let source = try Self.source(arguments, kind: kind)
        guard case let .file(id) = source, run.wordsInArt || run.makesMotion, let page = pages.page(for: id) else { return source }
        return .html(page)
    }
}
