//
//  ScreenshotHandUploads.swift
//  Atlas
//

import Foundation

/// Screenshot files an assistant sent to the upload link for this launch,
/// waiting to be named in `propose_screenshot_file`. Atlas is sandboxed,
/// so it can't read the assistant's files by path; the link's secret is
/// this launch's token, which only `get_screenshot_context` hands out.
@MainActor
final class ScreenshotHandUploads {
    static let shared = ScreenshotHandUploads()

    struct Upload: Hashable {
        var appID: StoreApp.ID
        var file: ScreenshotHandFile
        var hasTransparency: Bool
    }

    let token: String
    private(set) var uploads: [String: Upload] = [:]

    init(token: String = UUID().uuidString.lowercased()) {
        self.token = token
    }

    func add(_ upload: Upload) {
        uploads[upload.file.id] = upload
    }

    func upload(id: String, appID: StoreApp.ID) -> Upload? {
        guard let upload = uploads[id], upload.appID == appID else { return nil }
        return upload
    }

    func remove(id: String) {
        uploads[id] = nil
    }
}
