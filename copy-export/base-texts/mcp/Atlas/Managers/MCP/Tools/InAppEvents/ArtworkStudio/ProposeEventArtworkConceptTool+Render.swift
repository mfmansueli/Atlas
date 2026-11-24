//
//  ProposeEventArtworkConceptTool+Render.swift
//  Atlas
//

import Foundation

@MainActor
extension ProposeEventArtworkConceptTool {
    /// Renders one kind's page: a still per language when the name is
    /// drawn in ({{eventName}} becomes each language's name), else one for
    /// all; with motion, a loop of each too.
    func render(
        _ html: String, kind: InAppEventMedia.Kind, run: EventArtworkRun, event: InAppEvent, app: StoreApp
    ) async throws -> (stills: [EventArtworkImage], videos: [EventArtworkImage]) {
        let renderer = RenderEventArtworkTool(directory: directory, loopFrames: loopFrames)
        var stills: [EventArtworkImage] = []
        var videos: [EventArtworkImage] = []
        for locale in run.renderedLocales {
            let name = event.localization(locale)?.name ?? event.primaryLocalization?.name ?? event.referenceName
            let filled = Self.filled(html, eventName: name)
            let page = EventArtworkPage(html: filled, fileName: nil, kind: kind, locale: locale, event: event, app: app)
            let tag = run.wordsInArt ? locale : nil
            if let id = try await renderer.render(page, motion: false), let url = InAppEventArtworkFiles.url(id: id, appID: app.id, in: directory) {
                stills.append(EventArtworkImage(kind: kind, locale: tag, fileID: id, path: url.path(percentEncoded: false)))
            }
            if run.makesMotion, let id = try await renderer.render(page, motion: true),
               let url = InAppEventArtworkFiles.url(id: id, appID: app.id, in: directory)
            {
                videos.append(EventArtworkImage(kind: kind, locale: tag, fileID: id, path: url.path(percentEncoded: false), isVideo: true))
            }
        }
        return (stills, videos)
    }

    /// The page with {{eventName}} as `eventName`, escaped for HTML.
    static func filled(_ html: String, eventName: String) -> String {
        let escaped = eventName
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return html.replacingOccurrences(of: "{{eventName}}", with: escaped)
    }
}
