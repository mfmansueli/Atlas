//
//  ProductPageFilesFolder.swift
//  Atlas
//

import Foundation

/// Where Choose Files… keeps copies of the chosen screenshots until they're
/// pushed: `Application Support/Atlas/ProductPages/Files/<appID>/<set>/`,
/// so the push reads them even if the originals move. DEBUG scenes and
/// unit tests write to a temporary folder.
struct ProductPageFilesFolder: Sendable {
    let root: URL

    static var shared: ProductPageFilesFolder {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return temporary }
        #endif
        return ProductPageFilesFolder(root: URL.applicationSupportDirectory.appending(path: "Atlas/ProductPages/Files"))
    }

    static var temporary: ProductPageFilesFolder {
        ProductPageFilesFolder(root: FileManager.default.temporaryDirectory.appending(path: "AtlasPageFiles"))
    }

    /// Deletes the app's folders no queued change reads any more: a set
    /// pushed, discarded or replaced by another choice.
    func prune(appID: StoreApp.ID, keeping paths: Set<String>) {
        let appFolder = root.appending(path: appID)
        let folders = (try? FileManager.default.contentsOfDirectory(at: appFolder, includingPropertiesForKeys: nil)) ?? []
        for folder in folders {
            let prefix = folder.standardizedFileURL.path + "/"
            guard !paths.contains(where: { URL(fileURLWithPath: $0).standardizedFileURL.path.hasPrefix(prefix) }) else { continue }
            try? FileManager.default.removeItem(at: folder)
        }
    }

    /// Writes the files into a new folder of the app's and returns them as
    /// the push takes them, in the order chosen. Names are numbered so two
    /// files of the same name don't overwrite each other.
    func save(_ files: [ProductPageChosenFile], appID: StoreApp.ID) throws -> [ProductPageScreenshotsPush.File] {
        let folder = root.appending(path: appID).appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try files.enumerated().map { index, file in
            let url = folder.appending(path: String(format: "%02d-", index + 1) + file.fileName)
            try file.data.write(to: url, options: .atomic)
            return ProductPageScreenshotsPush.File(
                path: url.path, fileName: file.fileName, fileSize: file.data.count, checksum: ScreenshotPNG.checksum(file.data)
            )
        }
    }
}
