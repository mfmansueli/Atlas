//
//  AppPreviewUploads.swift
//  Atlas
//

import Foundation

/// App Preview videos an assistant sent to the upload link for this
/// launch, kept on this Mac and waiting to be named in
/// `propose_app_preview_file`. Atlas is sandboxed, so it can't read the
/// assistant's files by path; the link's secret is this launch's token,
/// which only `get_screenshot_context` hands out.
@MainActor
final class AppPreviewUploads {
    static let shared = AppPreviewUploads()

    struct Upload: Hashable {
        var id: String
        var appID: StoreApp.ID
        var file: ProductPageScreenshotsPush.File
        /// As it plays, its transform applied; nil when Atlas can't read it.
        var pixelSize: PixelSize?
        var seconds: Double?
    }

    let token: String
    private(set) var uploads: [String: Upload] = [:]

    init(token: String = UUID().uuidString.lowercased()) {
        self.token = token
    }

    func add(_ upload: Upload) {
        uploads[upload.id] = upload
    }

    func upload(id: String, appID: StoreApp.ID) -> Upload? {
        guard let upload = uploads[id], upload.appID == appID else { return nil }
        return upload
    }

    func remove(id: String) {
        uploads[id] = nil
    }
}
