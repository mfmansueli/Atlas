//
//  ScreenshotHandFilesFolder.swift
//  Atlas
//

import CoreGraphics
import Foundation
import ImageIO

/// Where screenshots given by hand are kept, as long as a set or a waiting
/// suggestion uses them: `Application Support/Atlas/Screenshots/ByHand/
/// <appID>/<file id>.png`, so the push reads them even if the originals
/// move. DEBUG scenes and unit tests write to a temporary folder.
struct ScreenshotHandFilesFolder: Sendable {
    let root: URL

    static var shared: ScreenshotHandFilesFolder {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return temporary }
        #endif
        return ScreenshotHandFilesFolder(root: URL.applicationSupportDirectory.appending(path: "Atlas/Screenshots/ByHand"))
    }

    static var temporary: ScreenshotHandFilesFolder {
        ScreenshotHandFilesFolder(root: FileManager.default.temporaryDirectory.appending(path: "AtlasHandScreenshots"))
    }

    func url(for file: ScreenshotHandFile, appID: StoreApp.ID) -> URL {
        root.appending(path: appID).appending(path: "\(file.id).\(file.pathExtension)")
    }

    /// Keeps `data` and returns it as a set takes it. The checksum is the
    /// bytes' MD5, which App Store Connect reports back once it's live.
    func save(
        _ data: Data,
        fileName: String,
        pixelSize: PixelSize,
        appID: StoreApp.ID,
        copiedFrom: String? = nil,
        proposedBy: String? = nil,
        date: Date = .now
    ) throws -> ScreenshotHandFile {
        let file = ScreenshotHandFile(
            id: UUID().uuidString, fileName: fileName, checksum: ScreenshotPNG.checksum(data), pixelSize: pixelSize, byteCount: data.count,
            copiedFrom: copiedFrom, proposedBy: proposedBy, addedAt: date
        )
        let url = url(for: file, appID: appID)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return file
    }

    func data(for file: ScreenshotHandFile, appID: StoreApp.ID) throws -> Data {
        try Data(contentsOf: url(for: file, appID: appID))
    }

    /// The file about `pixelWidth` pixels wide, for thumbnails and viewers.
    func image(for file: ScreenshotHandFile, appID: StoreApp.ID, pixelWidth: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url(for: file, appID: appID) as CFURL, nil) else { return nil }
        // The thumbnail size is the long side's.
        let long = max(file.pixelSize.width, file.pixelSize.height)
        let wanted = Int((Double(max(1, pixelWidth)) * Double(long) / Double(max(1, file.pixelSize.width))).rounded())
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: min(long, max(1, wanted)),
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Deletes the app's files nothing uses any more.
    func prune(appID: StoreApp.ID, keeping fileIDs: Set<String>) {
        let folder = root.appending(path: appID)
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for url in files where !fileIDs.contains(url.deletingPathExtension().lastPathComponent) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
