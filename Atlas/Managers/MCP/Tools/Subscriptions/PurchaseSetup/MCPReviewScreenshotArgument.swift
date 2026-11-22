//
//  MCPReviewScreenshotArgument.swift
//  Atlas
//

import Foundation

/// A review screenshot an assistant names: the `fileId` the review
/// screenshot upload link returned, or a PNG or JPEG's path when Atlas may
/// read it (the sandbox lets it read few).
@MainActor
enum MCPReviewScreenshotArgument {
    static let description = """
    The App Review screenshot (the paywall or purchase as the app shows it, PNG or JPEG): the fileId the \
    reviewScreenshotUploadURL from get_subscriptions returned, or a file path Atlas can read.
    """

    /// The file for `argument`; nil when it's left out. Throws a reason
    /// the assistant can act on.
    static func file(
        _ argument: String?,
        appID: StoreApp.ID,
        uploads: PurchaseReviewScreenshotUploads = .shared,
        folder: PurchaseReviewScreenshotFolder = .shared
    ) throws -> PurchaseReviewScreenshotFile? {
        guard let value = argument?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        if let file = uploads.file(id: value, appID: appID) { return file }
        let path = (value as NSString).expandingTildeInPath
        guard path.hasPrefix("/") else {
            throw MCPToolError.invalidArgument(
                name: "reviewScreenshot", expected: String(localized: "a fileId from this launch's reviewScreenshotUploadURL (see get_subscriptions)")
            )
        }
        let url = URL(filePath: path)
        guard let data = try? Data(contentsOf: url) else {
            throw MCPToolError.invalidArgument(
                name: "reviewScreenshot",
                expected: String(localized: """
                a file Atlas can read: Atlas is sandboxed, so send it to reviewScreenshotUploadURL from get_subscriptions \
                with curl --data-binary @file.png and pass the fileId it returns
                """)
            )
        }
        let file = try folder.save(data, fileName: url.lastPathComponent, appID: appID)
        uploads.add(file, appID: appID)
        return file
    }
}
