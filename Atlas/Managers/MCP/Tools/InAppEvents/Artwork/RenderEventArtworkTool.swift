//
//  RenderEventArtworkTool.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// `render_event_artwork`: makes or checks an In-App Event's card or
/// details page in one language. An HTML page renders as a still at the
/// largest size Apple takes; a file from the upload link (or a small image
/// in base64) is read as it is. It returns the art, the art as the App
/// Store lays the event's text over it, and the checks. Nothing is queued.
struct RenderEventArtworkTool: MCPTool {
    /// Where the files are kept; tests use their own folder.
    var directory = InAppEventArtworkFiles.directory
    /// How many frames a page's loop gets; nil is the whole 20 seconds
    /// (tests make a few).
    var loopFrames: Int?
    /// Where each render's page is kept, for a concept sent by file id.
    var pages = EventArtworkRenderedPages.shared
    /// The person's Make the Artwork runs: while one waits for concepts,
    /// the render points at propose_event_artwork_concept.
    var studio = EventArtworkStudio.shared

    /// The longer side of the images the assistant gets back.
    static let previewPixels = 1280
    /// Base64 images above this go through the upload link instead.
    static let maximumBase64Bytes = 24 * 1024 * 1024

    let definition = MCPToolDefinition(
        name: "render_event_artwork",
        title: "Render In-App Event artwork",
        description: """
        Makes or checks one In-App Event's card (16:9, shown in search, Today and on the product page) or details page \
        (9:16, the top of the event's page) in one language: the art Apple shows behind the event's badge, name and \
        description. Give exactly one of: `html`, a full HTML page Atlas renders as a still at 3840 × 2160 (card) or \
        2160 × 3840 (details page), or with `motion: true` as a video: its CSS and SVG animation as a 20-second seamless \
        loop at 30 fps, 1920 × 1080 or 1080 × 1920 (page JavaScript doesn't run); `fileId`, a PNG, JPEG, MP4 or MOV \
        sent to the upload link get_in_app_events gives \
        (`curl --data-binary @card.mp4 '<link>?name=card.mp4'`), e.g. stills or loops an app's own tools render; or \
        `imageBase64`, a PNG or JPEG under 24 MB. Returns the art, the same art as the App Store lays the badge, the name \
        and the description (short on the card, long on the details page) over it in `locale`, and its checks against \
        Apple's rules: `refusals` (size outside 1920 × 1080–3840 × 2160 or 1080 × 1920–2160 × 3840, not exactly 16:9 or \
        9:16, wrong format, not 30 or 60 fps, a video shorter than 5 s or longer than 30 s, audio that isn't stereo AAC/PCM \
        at 44.1 or 48 kHz, over 500 MB) must be fixed before propose_event_artwork takes it; `warnings` (text in the art, \
        a busy lower part where Apple puts the name, transparency, a codec Apple doesn't name) are worth fixing. With \
        `motionFrames`, a page's loop is shown at a few moments and checked, quickly. Make art without words, \
        logos, borders or gradients, a calm lower part, and a seamless loop for a video. Returns a `fileId` to propose. \
        Read-only: nothing is queued.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "eventId": MCPToolDefinition.string("The event's id, from get_in_app_events."),
                "kind": ["type": "string", "enum": ["card", "details"], "description": "card (16:9) or details (9:16)."],
                "locale": MCPToolDefinition.string("The language to lay the event's text in, e.g. de-DE. Default: the event's primary language."),
                "html": MCPToolDefinition.string("A full HTML page to render as the art, with no text in it."),
                "fileId": MCPToolDefinition.string("A file sent to the upload link, or one this tool returned."),
                "imageBase64": MCPToolDefinition.string("A PNG or JPEG, base64-encoded."),
                "fileName": MCPToolDefinition.string("The name Apple gets for an html or imageBase64 file, e.g. gratitude-card.png."),
                "motion": [
                    "type": "boolean",
                    "description": """
                    With html: render the page's CSS and SVG animation as a 20-second seamless loop (a video, its first \
                    frame the poster) instead of a still. Takes about a minute. Default false.
                    """,
                ],
                "motionFrames": [
                    "type": "boolean",
                    "description": """
                    With html: also return the page's loop at four moments, and whether its animations repeat \
                    evenly in 20 s and the end meets the start, without making the video (seconds, not a minute). Use it \
                    to check motion before sending a concept. Default false.
                    """,
                ],
                "posterSeconds": ["type": "number", "description": "A video's poster frame, in seconds from the start. Default 0."],
            ],
            required: ["appId", "eventId", "kind"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let event = try await Self.event(arguments.string("eventId"), of: app, in: context)
        guard let kind = try InAppEventMedia.Kind(mcpValue: arguments.string("kind")) else {
            throw MCPToolError.invalidArgument(name: "kind", expected: String(localized: "card or details"))
        }
        let locale = try arguments.optionalString("locale") ?? event.primaryLocale ?? event.localizations.first?.locale ?? "en-US"
        let target = "\(app.name) · \(event.referenceName) · \(kind.title) · \(locale)"
        let fileID: String
        var framesPage: EventArtworkPage?
        switch try Self.source(arguments) {
        case let .refused(reason):
            return .refused(reason, target: target, details: ["uploadLink": .string(Self.uploadLink(app: app, port: context.port))])
        case let .file(id):
            fileID = id
        case let .base64(data, name):
            fileID = try InAppEventArtworkFiles.save(
                data, fileName: name, appID: app.id, in: directory, origin: InAppEventArtworkOrigin(source: .image, name: name)
            )
        case let .html(html, name):
            let page = EventArtworkPage(html: html, fileName: name, kind: kind, locale: locale, event: event, app: app)
            guard let rendered = try await render(page, motion: arguments.optionalBool("motion") ?? false) else {
                return .failed("The page rendered, but its PNG couldn’t be written.", target: target)
            }
            pages.remember(html, for: rendered)
            fileID = rendered
            if try arguments.optionalBool("motionFrames") ?? false { framesPage = page }
        }
        guard let report = try await InAppEventArtworkReport.make(
            fileID: fileID, appID: app.id, kind: kind, language: locale, posterSeconds: arguments.optionalDouble("posterSeconds") ?? 0,
            in: directory
        ) else {
            return .refused(
                "Atlas has no file “\(fileID)” it can read as an image or a video. Send a PNG, JPEG, MP4 or MOV to the upload link.",
                target: target, details: ["uploadLink": .string(Self.uploadLink(app: app, port: context.port))]
            )
        }
        let texts = InAppEventArtworkOverlayTexts(event: event, kind: kind, locale: locale, appName: app.name)
        var result = report.json
        result.merge(Self.infoJSON(of: report)) { old, _ in old }
        result["locale"] = .string(locale)
        result["overlay"] = .object(texts.json)
        result["then"] = .string(next(report, appID: app.id, eventID: event.id))
        var images = await Self.previewImages(of: report, kind: kind, texts: texts)
        if images.count == 2 { result["images"] = "the art, then the art with the event's text as the App Store lays it" }
        if let framesPage {
            let frames = try await motionFrames(framesPage)
            result["motionFrames"] = frames.json
            images += frames.images
        }
        return MCPToolOutcome(result: .object(result), isError: false, logLines: [.init(target: target, outcome: .read)], images: images)
    }

    /// The art, then the art under the event's text as the App Store lays
    /// it, as JPEGs for the assistant to look at.
    private static func previewImages(
        of report: InAppEventArtworkReport, kind: InAppEventMedia.Kind, texts: InAppEventArtworkOverlayTexts
    ) async -> [MCPToolOutcome.ImageContent] {
        guard let still = report.still else { return [] }
        var images: [MCPToolOutcome.ImageContent] = []
        if let art = InAppEventArtworkInspector.jpeg(still, maxPixel: previewPixels) {
            images.append(MCPToolOutcome.ImageContent(data: art, mimeType: "image/jpeg"))
        }
        if let laid = await InAppEventArtworkOverlayRenderer.render(still, kind: kind, texts: texts),
           let overlay = InAppEventArtworkInspector.jpeg(laid, maxPixel: previewPixels)
        {
            images.append(MCPToolOutcome.ImageContent(data: overlay, mimeType: "image/jpeg"))
        }
        return images
    }

    /// The file's original name, SHA-256 and origin; nothing for a file
    /// kept before Atlas wrote them.
    private static func infoJSON(of report: InAppEventArtworkReport) -> [String: JSONValue] {
        InAppEventArtworkFiles.info(atPath: report.url.path(percentEncoded: false))?.json ?? [:]
    }

    /// What to do with the render: fix it, send it in a concept when the
    /// person asked for concepts in Atlas, or queue it.
    private func next(_ report: InAppEventArtworkReport, appID: StoreApp.ID, eventID: InAppEvent.ID) -> String {
        guard report.canQueue else { return "fix the refusals, then render again" }
        guard studio.run(appID: appID, eventID: eventID)?.step == .making else {
            return "propose_event_artwork with this fileId, for every language or some"
        }
        return """
        The person asked for concepts in Atlas: once the card and the details image pass the brief's selfCheck, send \
        them together with propose_event_artwork_concept (this fileId or the page), not propose_event_artwork.
        """
    }

    /// Where the art comes from.
    enum Source {
        case html(String, name: String?)
        case file(String)
        case base64(Data, name: String?)
        case refused(String)
    }

    static func source(_ arguments: MCPToolArguments) throws -> Source {
        let html = try arguments.optionalString("html")
        let fileID = try arguments.optionalString("fileId")
        let base64 = try arguments.optionalString("imageBase64")
        let name = try arguments.optionalString("fileName")
        let given = [html, fileID, base64].compactMap(\.self)
        guard given.count == 1 else {
            return .refused(given.isEmpty
                ? "Give the art: html, a fileId from the upload link, or imageBase64."
                : "Give only one of html, fileId and imageBase64.")
        }
        if let html { return .html(html, name: name) }
        if let fileID { return .file(fileID) }
        guard let base64, let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters), !data.isEmpty else {
            return .refused("imageBase64 isn’t base64 of a PNG or JPEG.")
        }
        guard data.count <= maximumBase64Bytes else { return .refused("The image is over 24 MB: send it to the upload link instead.") }
        guard let sniffed = InAppEventArtworkFiles.sniffedExtension(data), ["png", "jpg"].contains(sniffed) else {
            return .refused("imageBase64 takes a PNG or JPEG; send a video to the upload link.")
        }
        return .base64(data, name: name)
    }

    /// The event, read from App Store Connect. A failed read is tried once
    /// more after `retryAfter`: on Alba (2026-11-18) one 403 in the middle of
    /// a run cost a whole concept, and the next read worked.
    static func event(
        _ id: String, of app: StoreApp, in context: MCPToolContext, retryAfter: Duration = .seconds(2)
    ) async throws -> InAppEvent {
        let services = context.workspace.services.inAppEvents
        let events: [InAppEvent]
        do {
            events = try await services.events(for: app)
        } catch {
            try await Task.sleep(for: retryAfter)
            events = try await services.events(for: app)
        }
        guard let event = events.first(where: { $0.id == id }) else {
            throw MCPToolError.notFound(String(localized: "\(app.name) has no In-App Event “\(id)”. Use the ids from get_in_app_events."))
        }
        return event
    }

    static func uploadLink(app: StoreApp, port: UInt16) -> String {
        MCPEndpoint.eventArtworkUploadURL(port: port, token: InAppEventArtworkFiles.uploadToken, appID: app.id)
    }
}
