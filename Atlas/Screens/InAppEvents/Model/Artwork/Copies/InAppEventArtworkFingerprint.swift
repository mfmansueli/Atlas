//
//  InAppEventArtworkFingerprint.swift
//  Atlas
//

import Foundation

/// What tells whether two event art files are the same: the same file on
/// this Mac, the same SHA-256, or, when one side's SHA-256 isn't known (App
/// Store Connect's media, files kept before Atlas wrote their info), the
/// name and size it was uploaded with.
struct InAppEventArtworkFingerprint: Hashable, Sendable {
    var path: String?
    var sha256: String?
    var fileName: String?
    var fileSize: Int?

    init(path: String? = nil, sha256: String? = nil, fileName: String? = nil, fileSize: Int? = nil) {
        self.path = path
        self.sha256 = sha256
        self.fileName = fileName
        self.fileSize = fileSize
    }

    /// The file a queued upload sends.
    init(_ push: InAppEventArtworkPush, info: InAppEventArtworkFileInfo?) {
        self.init(path: push.path, sha256: info?.sha256, fileName: push.fileName, fileSize: push.fileSize)
    }

    /// A file read and checked.
    init(_ report: InAppEventArtworkReport, info: InAppEventArtworkFileInfo?) {
        self.init(path: report.url.path(percentEncoded: false), sha256: info?.sha256, fileName: report.file.fileName, fileSize: report.file.fileSize)
    }

    /// An image or video in App Store Connect, with the file on this Mac it
    /// was uploaded from when Atlas still has one by that name and size.
    init(_ media: InAppEventMedia, stored: [InAppEventArtworkStoredFile]) {
        let matches = InAppEventArtworkStoredFile.matching(fileName: media.fileName, fileSize: media.fileSize, in: stored)
        let hashes = Set(matches.compactMap(\.info?.sha256))
        self.init(
            path: matches.count == 1 ? matches.first?.path : nil, sha256: hashes.count == 1 && matches.allSatisfy { $0.info != nil } ? hashes.first : nil,
            fileName: media.fileName, fileSize: media.fileSize
        )
    }

    func isSameFile(as other: InAppEventArtworkFingerprint) -> Bool {
        if let path, path == other.path { return true }
        if let sha256, let theirs = other.sha256 { return sha256 == theirs }
        guard let fileName, let fileSize else { return false }
        return fileName == other.fileName && fileSize == other.fileSize
    }
}
