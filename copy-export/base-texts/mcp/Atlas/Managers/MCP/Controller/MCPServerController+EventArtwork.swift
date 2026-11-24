//
//  MCPServerController+EventArtwork.swift
//  Atlas
//

import Foundation

/// The In-App Event art upload link: an assistant sends a card or details
/// page it made elsewhere (a PNG, JPEG, MP4 or MOV) with `curl
/// --data-binary`, then names the returned `fileId` in
/// `render_event_artwork` or `propose_event_artwork`. Atlas is
/// sandboxed, so it can't read the assistant's files by path. The link's
/// secret is this launch's token, which only `get_in_app_events` hands out
/// to a paired assistant.
extension MCPServerController {
    func receiveEventArtworkUpload(_ request: HTTPRequest) async -> HTTPResponse {
        guard Self.isLocal(origin: request.header("origin")), Self.isLocal(host: request.header("host")) else {
            return .text(403, "Only clients on this Mac may connect.")
        }
        guard request.method == "POST" || request.method == "PUT" else { return .text(405, headers: ["Allow": "POST, PUT"]) }
        let parts = request.path.dropFirst(MCPEndpoint.eventArtworkPath.count).split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count == 2, String(parts[0]) == InAppEventArtworkFiles.uploadToken else {
            return .json(["error": "Unknown upload link; call get_in_app_events for this launch's link."] as JSONValue, status: 404)
        }
        guard !request.body.isEmpty else {
            return .json(["error": "The body is empty: send the file's bytes with curl --data-binary @card.png."] as JSONValue, status: 400)
        }
        guard let workspace else { return .json(["error": "Atlas isn't ready yet; try again."] as JSONValue, status: 503) }
        do {
            let app = try await workspace.app(matching: String(parts[1]).removingPercentEncoding ?? String(parts[1]))
            let name = Self.queryValue("name", in: request.target)
            let id = try InAppEventArtworkFiles.save(
                request.body, fileName: name, appID: app.id, in: eventArtworkDirectory, origin: InAppEventArtworkOrigin(source: .upload, name: name)
            )
            guard let url = InAppEventArtworkFiles.url(id: id, appID: app.id, in: eventArtworkDirectory),
                  let file = await InAppEventArtworkInspector.inspect(url)
            else {
                return .json(["error": "Atlas can't read this as an image or a video. Send a PNG, JPEG, MP4 or MOV."] as JSONValue, status: 422)
            }
            var result: [String: JSONValue] = [
                "fileId": .string(id),
                "fileName": .string(file.fileName),
                "isVideo": .bool(file.isVideo),
                "pixelSize": .string(file.pixelSize.title),
                "then": "render_event_artwork with this fileId to check it and see it with the event's text, then propose_event_artwork",
            ]
            if let seconds = file.seconds { result["seconds"] = .double((seconds * 10).rounded() / 10) }
            if let info = InAppEventArtworkFiles.info(atPath: url.path(percentEncoded: false)) { result["sha256"] = .string(info.sha256) }
            return .json(JSONValue.object(result))
        } catch {
            return .json(["error": .string(error.localizedDescription)] as JSONValue, status: 422)
        }
    }

    /// `name`'s value in a target like `/event-artwork/x/1?name=card.png`.
    nonisolated static func queryValue(_ name: String, in target: String) -> String? {
        URLComponents(string: "http://localhost\(target)")?.queryItems?.first { $0.name == name }?.value
    }
}
