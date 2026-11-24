//
//  MCPServerController+ScreenshotFiles.swift
//  Atlas
//

import Foundation

/// The screenshot file upload link: an assistant sends a PNG or JPEG it
/// made for a set with `curl --data-binary`, then names the returned
/// `fileId` in `propose_screenshot_file`. The file is kept as is: Atlas
/// never scales a screenshot.
extension MCPServerController {
    func receiveScreenshotFileUpload(_ request: HTTPRequest, uploads: ScreenshotHandUploads = .shared) async -> HTTPResponse {
        guard Self.isLocal(origin: request.header("origin")), Self.isLocal(host: request.header("host")) else {
            return .text(403, "Only clients on this Mac may connect.")
        }
        guard request.method == "POST" || request.method == "PUT" else { return .text(405, headers: ["Allow": "POST, PUT"]) }
        let parts = request.path.dropFirst(MCPEndpoint.screenshotFilePath.count).split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count == 2, String(parts[0]) == uploads.token else {
            return .json(["error": "Unknown upload link; call get_screenshot_context for this launch's link."] as JSONValue, status: 404)
        }
        guard !request.body.isEmpty else {
            return .json(["error": "The body is empty: send the file's bytes with curl --data-binary @01.png."] as JSONValue, status: 400)
        }
        guard let workspace else { return .json(["error": "Atlas isn't ready yet; try again."] as JSONValue, status: 503) }
        do {
            let app = try await workspace.app(matching: String(parts[1]).removingPercentEncoding ?? String(parts[1]))
            let name = Self.queryValue("name", in: request.target) ?? "screenshot.png"
            let chosen = ScreenshotHandChosenFile(fileName: name, data: request.body)
            guard let size = chosen.pixelSize else {
                return .json(["error": "Atlas can't read this as a PNG or JPEG image."] as JSONValue, status: 422)
            }
            let file = try workspace.services.screenshots.handFiles.save(request.body, fileName: name, pixelSize: size, appID: app.id)
            uploads.add(ScreenshotHandUploads.Upload(appID: app.id, file: file, hasTransparency: chosen.hasTransparency))
            let fits = ScreenshotDisplayType.studio.filter { ScreenshotHandSizes.accepts(size, on: $0) }.map { JSONValue.string($0.mcpValue) }
            var result: [String: JSONValue] = [
                "fileId": .string(file.id),
                "fileName": .string(name),
                "pixelSize": .string(size.title),
                "fitsDisplayTypes": .array(fits),
                "then": "propose_screenshot_file with this fileId, the locale, displayType and the position it replaces",
            ]
            if chosen.hasTransparency {
                result["warning"] = "It has transparency, which App Store Connect refuses: save it without an alpha channel and send it again."
            }
            return .json(JSONValue.object(result))
        } catch {
            return .json(["error": .string(error.localizedDescription)] as JSONValue, status: 422)
        }
    }
}
