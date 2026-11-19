//
//  GetEventArtworkBriefTool.swift
//  Atlas
//

import CoreGraphics
import Foundation
import ImageIO

/// `get_event_artwork_brief`: what the person asked for when they pressed
/// Make the Artwork on an event (board 47): the brief in their words, the
/// look to start from, the options, the event's texts, the app's design,
/// the sizes and rules, the concepts already sent, and a change asked for
/// one of them. Images come with it: the event's card when it's extended,
/// and the concept being changed.
struct GetEventArtworkBriefTool: MCPTool {
    var studio = EventArtworkStudio.shared
    var autopilot = AutopilotCenter.shared
    /// Reads the event's card for "Extend the card you have"; tests skip it.
    var loadsCard = true

    let definition = MCPToolDefinition(
        name: "get_event_artwork_brief",
        title: "Get the event artwork brief",
        description: """
        Reads the brief the person wrote when they pressed Make the Artwork on an In-App Event in Atlas: what the art \
        should show, the look to start from (`newLook`: three concepts in the app's brand; `template`: Atlas's event \
        layouts in the app's colors; `extendCard`: keep the event's card, attached, and make only the details image to \
        match), whether the event's name is drawn into the art (then write it as {{eventName}} and Atlas draws it in \
        each language), whether a moving version is made, the event's texts, the app's design (look, design project), \
        the art direction (the idea, where the App Store lays its text, the craft and the check of each render), the \
        sizes and rules, the concepts already sent, `otherEvents`: the ideas already drawn for the app's other events, \
        to stay different from, `revision`: the one concept to redraw and what the person asked for, with its images \
        attached, and `addMotion`: concepts to give motion as they are, with `motionDirection` (Apple's rules for event \
        videos and how the loop moves). Render and look at each image with render_event_artwork, then send each concept \
        with propose_event_artwork_concept.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "eventId": MCPToolDefinition.string("The event's id, from get_in_app_events or the prompt."),
            ],
            required: ["appId", "eventId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let eventID = try arguments.string("eventId")
        let target = "\(app.name) · \(eventID) · artwork brief"
        guard let run = studio.run(appID: app.id, eventID: eventID) else {
            return .refused(Self.noRun, target: target)
        }
        let event = try await RenderEventArtworkTool.event(eventID, of: app, in: context)
        let services = context.workspace.services
        var result: [String: JSONValue] = [
            "appId": .string(app.id),
            "eventId": .string(event.id),
            "event": Self.eventJSON(event, run: run),
            "brief": .string(run.brief),
            "look": Self.lookJSON(run, badge: event.badge, appName: app.name),
            "wordsInArt": .bool(run.wordsInArt),
            "motion": .bool(run.makesMotion),
            "kinds": .array(run.style.kinds.map { .string($0.mcpValue) }),
            "sizes": ["card": "3840 × 2160 (16:9)", "details": "2160 × 3840 (9:16)"],
            "artDirection": EventArtworkDirection.json,
            "rules": .array(Self.rules(run).map(JSONValue.string)),
            "design": InAppEventDesignFacts.json(
                look: services.storePage.appSupport?.profile(for: app.id)?.look,
                knowledge: services.storePage.appSupport?.knowledge(for: app.id),
                project: autopilot.designProject(for: app.id)
            ),
            "concepts": [
                "expected": .int(run.expectedCount),
                "sent": .array(run.concepts.filter(\.isMadeByClaudeDesign).map { ["conceptId": .string($0.id), "name": .string($0.name)] }),
            ],
        ]
        if run.makesMotion { result["motionDirection"] = EventArtworkMotion.json }
        if let others = EventArtworkOtherEvents.json(studio.runs(for: app.id), except: event.id) { result["otherEvents"] = others }
        var images: [MCPToolOutcome.ImageContent] = []
        if run.usesCapture { result["captures"] = await Self.captures(app: app, locale: run.primaryLocale, in: context) }
        if run.style == .extendCard, loadsCard, let card = await Self.card(of: event) {
            images.append(MCPToolOutcome.ImageContent(data: card, mimeType: "image/jpeg"))
            result["existingCard"] = "attached: the event's card as it is on the App Store. Make the details image to match it."
        }
        if let revising = run.revising {
            result["revision"] = Self.revisionJSON(revising, request: run.revisionRequest ?? "")
            for kind in revising.kinds {
                guard let still = revising.still(kind, locale: run.primaryLocale),
                      let image = await InAppEventArtworkInspector.still(URL(filePath: still.path), isVideo: false),
                      let jpeg = InAppEventArtworkInspector.jpeg(image, maxPixel: RenderEventArtworkTool.previewPixels)
                else { continue }
                images.append(MCPToolOutcome.ImageContent(data: jpeg, mimeType: "image/jpeg"))
            }
        }
        if run.isAnimating {
            result["addMotion"] = .array(run.animating.map(Self.motionJSON))
            for concept in run.animating {
                guard let still = concept.still(.card, locale: run.primaryLocale),
                      let image = await InAppEventArtworkInspector.still(URL(filePath: still.path), isVideo: false),
                      let jpeg = InAppEventArtworkInspector.jpeg(image, maxPixel: RenderEventArtworkTool.previewPixels)
                else { continue }
                images.append(MCPToolOutcome.ImageContent(data: jpeg, mimeType: "image/jpeg"))
            }
        }
        result["then"] = .string(Self.next(run))
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: target, outcome: .read)], images: images)
    }

    static let noRun = """
    The person hasn't asked for this event's artwork in Atlas: they start it with Make the Artwork… on the event. To \
    make art without it, use render_event_artwork and propose_event_artwork.
    """

    private static func eventJSON(_ event: InAppEvent, run: EventArtworkRun) -> JSONValue {
        var object: [String: JSONValue] = ["referenceName": .string(event.referenceName), "dates": .string(event.datesText)]
        if let badge = event.badge { object["badge"] = .string(badge.title) }
        if let texts = event.localization(run.primaryLocale) ?? event.primaryLocalization {
            object["name"] = .string(texts.name)
            object["shortDescription"] = .string(texts.shortDescription)
            object["longDescription"] = .string(texts.longDescription)
        }
        if run.wordsInArt {
            object["namesByLanguage"] = .object(Dictionary(
                run.locales.compactMap { code in event.localization(code).map { (code, JSONValue.string($0.name)) } }
            ) { first, _ in first })
        }
        return .object(object)
    }

    private static func lookJSON(_ run: EventArtworkRun, badge: InAppEventBadge?, appName: String) -> JSONValue {
        var object: [String: JSONValue] = ["style": .string(run.style.rawValue), "title": .string(run.style.title)]
        switch run.style {
        case .newLook:
            object["how"] = .string("""
            Three concepts that are different ideas (for example a wide scene, a close-up of one subject, a gathering of \
            lights or figures), each a card and a details image from one world, recomposed for each frame so they read \
            as a pair. Mark the one you'd choose as pick.
            """)
        case .template:
            object["how"] = .string("""
            Three concepts, one from each of the first three layouts here, in \(appName)'s colors and its own world. A \
            layout is a composition to start from, not a picture to copy: make each a full scene, crafted as artDirection \
            says. The first suits the event's badge, so events with the same badge share it: what makes the art this \
            event's is its subject, taken from this event's own texts, never the layout alone.
            """)
            object["templates"] = .array(EventArtworkTemplate.ordered(for: badge).map(\.json))
        case .extendCard:
            object["how"] = .string("""
            Keep the attached card as it is. Make three versions of the details image (9:16) that continue it: the same \
            colors, light and subject, recomposed for the tall frame. Send only details.
            """)
        }
        return .object(object)
    }

    private static func rules(_ run: EventArtworkRun) -> [String] {
        var rules = [
            """
            Keep the lower part (from 60% of the height down) dark and quiet for the App Store's white text, but part of \
            the scene: never an empty band.
            """,
            "No logos, borders or gradient overlays of your own; the App Store lays its own fade under the text.",
            "A full HTML page per image with CSS and inline SVG; JavaScript doesn't run and nothing loads from the web.",
        ]
        rules.append(run.wordsInArt
            ? """
            Draw the event's name once, as {{eventName}} in the page: Atlas puts each language's name there. Leave room for \
            longer names (German) and right-to-left ones (Arabic).
            """
            : "No words in the art: the App Store writes the event's text in every language.")
        if run.makesMotion {
            rules.append("""
            Give each page CSS or SVG animation that loops seamlessly over 20 seconds, as motionDirection says: one thing \
            that tells the event moves, slowly, the camera stays put, the first frame is complete on its own (Atlas keeps it \
            as the still) and nothing flashes. Check it with render_event_artwork's motionFrames before sending.
            """)
        }
        return rules
    }

    private static func revisionJSON(_ concept: EventArtworkConcept, request: String) -> JSONValue {
        var pages: [String: JSONValue] = [:]
        for (kind, html) in concept.pages { pages[kind.mcpValue] = .string(html) }
        return [
            "conceptId": .string(concept.id),
            "name": .string(concept.name),
            "request": .string(request),
            "pages": .object(pages),
            "images": "attached: the concept as it is, card first",
        ]
    }

    /// A concept to give motion: its pages, to animate as they are.
    private static func motionJSON(_ concept: EventArtworkConcept) -> JSONValue {
        var pages: [String: JSONValue] = [:]
        for (kind, html) in concept.pages { pages[kind.mcpValue] = .string(html) }
        return [
            "conceptId": .string(concept.id),
            "name": .string(concept.name),
            "why": .string(concept.why),
            "pages": .object(pages),
        ]
    }

    private static func next(_ run: EventArtworkRun) -> String {
        if run.isAnimating {
            let names = run.animating.map { "“\($0.name)” (\($0.id))" }.joined(separator: ", ")
            return """
            The person liked these concepts and asked for them to move: \(names). Keep each drawing exactly as it is (its \
            composition, colors and subject) and add CSS or SVG animation to both its pages, as motionDirection says. Check \
            each with render_event_artwork and motionFrames: true, then send it with propose_event_artwork_concept, the same \
            name and why, its two pages and replaces: its conceptId. One call per concept, then finish.
            """
        }
        if let revising = run.revising {
            return """
            Redraw only “\(revising.name)” as the person asked, render it with render_event_artwork and look at it under \
            the App Store's text, then send it with propose_event_artwork_concept and replaces: "\(revising.id)". Then finish.
            """
        }
        let left = max(0, run.expectedCount - run.designedCount)
        guard left > 0 else { return "Every concept is in: the person chooses in Atlas. Finish." }
        return """
        Render each image with render_event_artwork and check it against artDirection's selfCheck, then send \(left) more \
        concept\(left == 1 ? "" : "s") with propose_event_artwork_concept, one call each, then finish.
        """
    }

    /// The captures of the primary language, to look at with get_capture.
    private static func captures(app: StoreApp, locale: String, in context: MCPToolContext) async -> JSONValue {
        guard let draft = try? await MCPScreenshotsDraft.load(app: app.id, in: context.workspace) else {
            return .string("none yet: \(app.name) has no captures in Atlas. Design from the look and the project.")
        }
        var list: [JSONValue] = []
        for display in draft.document.renderedDisplays {
            for slot in 0..<draft.document.slotCount {
                guard let resolved = draft.document.captures.capture(locale: locale, displayType: display, slot: slot, primary: draft.primary.code)
                else { continue }
                list.append(["captureId": .string(resolved.capture.id), "displayType": .string(display.mcpValue), "slot": .int(slot + 1)])
            }
        }
        guard !list.isEmpty else { return "none yet: design from the look and the project." }
        return [
            "use": """
            Look at them with get_capture and take the screen the event is about as reference for the subject and colors. \
            Don't put the app's interface in the art.
            """,
            "list": .array(list),
        ]
    }

    /// The event's card from the App Store, as a JPEG.
    private static func card(of event: InAppEvent) async -> Data? {
        guard let url = event.media(.card)?.imageURL, !(event.media(.card)?.isVideo ?? false),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return InAppEventArtworkInspector.jpeg(image, maxPixel: RenderEventArtworkTool.previewPixels)
    }
}
