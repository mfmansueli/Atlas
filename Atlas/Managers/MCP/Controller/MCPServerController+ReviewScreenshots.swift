//
//  MCPServerController+ReviewScreenshots.swift
//  Atlas
//

import Foundation

/// The review screenshot upload link: an assistant sends the PNG or JPEG of
/// a subscription's or in-app purchase's paywall with `curl --data-binary`,
/// then names the returned `fileId` in `propose_purchase_review_screenshot`
/// (or as `reviewScreenshot` in `propose_subscription` and
/// `propose_in_app_purchase`). The bytes are kept as sent.
extension MCPServerController {
    func receiveReviewScreenshotUpload(
        _ request: HTTPRequest,
        uploads: PurchaseReviewScreenshotUploads = .shared,
        folder: PurchaseReviewScreenshotFolder = .shared
    ) async -> HTTPResponse {
        guard Self.isLocal(origin: request.header("origin")), Self.isLocal(host: request.header("host")) else {
            return .text(403, "Only clients on this Mac may connect.")
        }
        guard request.method == "POST" || request.method == "PUT" else { return .text(405, headers: ["Allow": "POST, PUT"]) }
        let parts = request.path.dropFirst(MCPEndpoint.reviewScreenshotPath.count).split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count == 2, String(parts[0]) == uploads.token else {
            return .json(["error": "Unknown upload link; call get_subscriptions for this launch's reviewScreenshotUploadURL."] as JSONValue, status: 404)
        }
        guard !request.body.isEmpty else {
            return .json(["error": "The body is empty: send the file's bytes with curl --data-binary @paywall.png."] as JSONValue, status: 400)
        }
        guard let workspace else { return .json(["error": "Atlas isn't ready yet; try again."] as JSONValue, status: 503) }
        do {
            let app = try await workspace.app(matching: String(parts[1]).removingPercentEncoding ?? String(parts[1]))
            let name = Self.queryValue("name", in: request.target) ?? "review-screenshot.png"
            let file = try folder.save(request.body, fileName: name, appID: app.id)
            uploads.add(file, appID: app.id)
            let result: JSONValue = [
                "fileId": .string(file.id),
                "fileName": .string(file.fileName),
                "pixelSize": .string(file.pixelSize.title),
                "then": """
                propose_purchase_review_screenshot with this fileId and the productId, or reviewScreenshot in \
                propose_subscription / propose_in_app_purchase
                """,
            ]
            return .json(result)
        } catch {
            return .json(["error": .string(error.localizedDescription)] as JSONValue, status: 422)
        }
    }
}
