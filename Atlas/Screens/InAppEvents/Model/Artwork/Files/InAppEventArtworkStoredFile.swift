//
//  InAppEventArtworkStoredFile.swift
//  Atlas
//

import Foundation

/// One event art file kept on this Mac for an app, as
/// `InAppEventArtworkFiles.stored(appID:)` lists them: enough to tell
/// which one an image or video in App Store Connect is (Apple keeps the
/// name and size Atlas sent).
struct InAppEventArtworkStoredFile: Hashable, Sendable {
    var fileID: String
    var url: URL
    var fileName: String
    var fileSize: Int
    var info: InAppEventArtworkFileInfo?

    var path: String { url.path(percentEncoded: false) }

    /// The files named `fileName` of `fileSize` bytes, newest first.
    static func matching(fileName: String?, fileSize: Int?, in files: [InAppEventArtworkStoredFile]) -> [InAppEventArtworkStoredFile] {
        guard let fileName, let fileSize else { return [] }
        return files
            .filter { $0.fileName == fileName && $0.fileSize == fileSize }
            .sorted { ($0.info?.savedAt ?? .distantPast) > ($1.info?.savedAt ?? .distantPast) }
    }
}
