//
//  PurchaseReviewScreenshotFolder.swift
//  Atlas
//

import Foundation

/// Where App Review screenshots of subscriptions and in-app purchases wait
/// for the push: `Application Support/Atlas/ReviewScreenshots/<appID>/<file
/// id>.png`, so the push reads them even if the originals move. DEBUG
/// scenes and unit tests write to a temporary folder.
struct PurchaseReviewScreenshotFolder: Sendable {
    let root: URL

    static var shared: PurchaseReviewScreenshotFolder {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return temporary }
        #endif
        return PurchaseReviewScreenshotFolder(root: URL.applicationSupportDirectory.appending(path: "Atlas/ReviewScreenshots"))
    }

    static var temporary: PurchaseReviewScreenshotFolder {
        PurchaseReviewScreenshotFolder(root: FileManager.default.temporaryDirectory.appending(path: "AtlasReviewScreenshots"))
    }

    func url(for file: PurchaseReviewScreenshotFile, appID: StoreApp.ID) -> URL {
        root.appending(path: appID).appending(path: "\(file.id).\(file.pathExtension)")
    }

    /// The path the push reads.
    func path(for file: PurchaseReviewScreenshotFile, appID: StoreApp.ID) -> String {
        url(for: file, appID: appID).path(percentEncoded: false)
    }

    /// Checks `data` is a PNG or JPEG large enough, and keeps it.
    func save(_ data: Data, fileName: String, appID: StoreApp.ID) throws -> PurchaseReviewScreenshotFile {
        let size = try Self.check(data, fileName: fileName)
        let file = PurchaseReviewScreenshotFile(
            id: UUID().uuidString, fileName: fileName, checksum: ScreenshotPNG.checksum(data), pixelSize: size, byteCount: data.count
        )
        let url = url(for: file, appID: appID)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return file
    }

    /// The image's size; throws `PurchaseReviewScreenshotProblem`.
    static func check(_ data: Data, fileName: String) throws -> PixelSize {
        guard let size = ScreenshotHandChosenFile(fileName: fileName, data: data).pixelSize else {
            throw PurchaseReviewScreenshotProblem.notAnImage(fileName: fileName)
        }
        guard min(size.width, size.height) >= PurchaseReviewScreenshotFile.minimumSide else {
            throw PurchaseReviewScreenshotProblem.tooSmall(size)
        }
        return size
    }
}
