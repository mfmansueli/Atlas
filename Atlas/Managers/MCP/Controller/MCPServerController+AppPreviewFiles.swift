//
//  MCPServerController+AppPreviewFiles.swift
//  Atlas
//

import Foundation

/// The App Preview upload link: an assistant sends a MOV, MP4 or M4V it
/// made for a set with `curl --data-binary`, then names the returned
/// `fileId` in `propose_app_preview_file`. The video is kept as is.
extension MCPServerController {
    func receiveAppPreviewFileUpload(
        _ request: HTTPRequest, uploads: AppPreviewUploads = .shared, folder: ProductPageFilesFolder = .appPreviews
    ) async -> HTTPResponse {
        guard Self.isLocal(origin: request.header("origin")), Self.isLocal(host: request.header("host")) else {
            return .text(403, "Only clients on this Mac may connect.")
        }
        guard request.method == "POST" || request.method == "PUT" else { return .text(405, headers: ["Allow": "POST, PUT"]) }
        let parts = request.path.dropFirst(MCPEndpoint.appPreviewFilePath.count).split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count == 2, String(parts[0]) == uploads.token else {
            return .json(["error": "Unknown upload link; call get_screenshot_context for this launch's link."] as JSONValue, status: 404)
        }
        guard !request.body.isEmpty else {
            return .json(["error": "The body is empty: send the video's bytes with curl --data-binary @preview.mov."] as JSONValue, status: 400)
        }
        guard let workspace else { return .json(["error": "Atlas isn't ready yet; try again."] as JSONValue, status: 503) }
        do {
            let app = try await workspace.app(matching: String(parts[1]).removingPercentEncoding ?? String(parts[1]))
            let name = Self.queryValue("name", in: request.target) ?? "preview.mov"
            let chosen = ProductPageChosenVideo(fileName: name, data: request.body, pixelSize: nil, seconds: nil)
            guard let file = try folder.save([chosen], appID: app.id).first else { throw CocoaError(.fileWriteUnknown) }
            let facts = await ProductPagesViewModel.videoFacts(of: URL(fileURLWithPath: file.path))
            let id = "apf-" + UUID().uuidString.prefix(8).lowercased()
            uploads.add(AppPreviewUploads.Upload(id: id, appID: app.id, file: file, pixelSize: facts.size, seconds: facts.seconds))
            return .json(Self.appPreviewUploadResult(id: id, fileName: name, size: facts.size, seconds: facts.seconds))
        } catch {
            return .json(["error": .string(error.localizedDescription)] as JSONValue, status: 422)
        }
    }

    /// The upload's `fileId`, what Atlas read of it and the devices whose
    /// size it is.
    nonisolated static func appPreviewUploadResult(id: String, fileName: String, size: PixelSize?, seconds: Double?) -> JSONValue {
        let fits = AppPreviewSpec.displayTypes.filter { display in
            guard let size, let spec = AppPreviewSpec.spec(for: display, landscape: false) else { return false }
            return size == spec.pixelSize || size == spec.pixelSize.rotated
        }
        var result: [String: JSONValue] = [
            "fileId": .string(id),
            "fileName": .string(fileName),
            "fitsDisplayTypes": .array(fits.map { .string($0.mcpValue) }),
            "then": "propose_app_preview_file with this fileId, the locale, displayType and the position it replaces",
        ]
        if let size { result["pixelSize"] = .string(size.title) } else { result["warning"] = "Atlas can't read this as a MOV, MP4 or M4V video." }
        if let seconds { result["seconds"] = .double((seconds * 10).rounded() / 10) }
        return .object(result)
    }
}
