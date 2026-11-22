//
//  ScreenshotHandFile.swift
//  Atlas
//

import Foundation

/// A screenshot someone gave Atlas by hand (Add Screenshots…, Replace…,
/// Import a Folder…, a drop) or that Start from English (U.S.) copied from
/// another language: kept on this Mac (`ScreenshotHandFilesFolder`) until
/// the set no longer uses it. Atlas never scales or edits it; the push
/// uploads these exact bytes.
struct ScreenshotHandFile: Codable, Hashable, Sendable, Identifiable {
    var id: String
    /// The name it had, and the name App Store Connect gets.
    var fileName: String
    /// The MD5 of the file, as App Store Connect reports it back in
    /// `sourceFileChecksum`: that's how Atlas knows it's live.
    var checksum: String
    var pixelSize: PixelSize
    var byteCount: Int
    /// The language it was copied from by Start from English (U.S.); nil
    /// when the person chose the file.
    var copiedFrom: String?
    /// The assistant that suggested it (`propose_screenshot_file`), once
    /// accepted: Review & Push tags it with the assistant.
    var proposedBy: String?
    var addedAt: Date

    /// `png` or `jpg`: the extension the kept copy has.
    var pathExtension: String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return ext == "jpeg" || ext == "jpg" ? "jpg" : "png"
    }
}
