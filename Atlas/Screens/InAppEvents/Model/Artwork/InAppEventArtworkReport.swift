//
//  InAppEventArtworkReport.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// An event card or details page file read and checked: what it is, the
/// still the checks looked at (a video's poster frame), and the checks.
struct InAppEventArtworkReport: @unchecked Sendable {
    var fileID: String
    var url: URL
    var kind: InAppEventMedia.Kind
    var file: InAppEventArtworkFile
    /// The image, or the video's frame at `posterSeconds`.
    var still: CGImage?
    var posterSeconds: Double
    var look: InAppEventArtworkLook?
    var checks: [InAppEventArtworkCheck]

    var canQueue: Bool { InAppEventArtworkChecker.canQueue(checks) }

    /// A video's poster frame as Apple takes it, "00:00:02:00".
    var previewFrameTimeCode: String? {
        file.isVideo ? InAppEventArtworkRules.timeCode(seconds: posterSeconds, frameRate: file.frameRate ?? 30) : nil
    }

    /// Reads and checks the file `fileID` of `appID` as `kind`, looking
    /// for text in `language`; nil when there's no such file or it's
    /// neither an image nor a video.
    static func make(
        fileID: String, appID: StoreApp.ID, kind: InAppEventMedia.Kind, language: String, posterSeconds: Double = 0,
        in directory: URL = InAppEventArtworkFiles.directory
    ) async -> InAppEventArtworkReport? {
        guard let url = InAppEventArtworkFiles.url(id: fileID, appID: appID, in: directory),
              let file = await InAppEventArtworkInspector.inspect(url)
        else { return nil }
        let seconds = file.isVideo ? min(max(0, posterSeconds), max(0, (file.seconds ?? 0) - 0.05)) : 0
        let still = await InAppEventArtworkInspector.still(url, isVideo: file.isVideo, at: seconds)
        let look: InAppEventArtworkLook? = if let still { await InAppEventArtworkLook.read(still, language: language) } else { nil }
        return InAppEventArtworkReport(
            fileID: fileID, url: url, kind: kind, file: file, still: still, posterSeconds: seconds, look: look,
            checks: InAppEventArtworkChecker.checks(file, kind: kind, look: look)
        )
    }

    /// The checks, the file's facts and what to do next, for the tools.
    var json: [String: JSONValue] {
        var object: [String: JSONValue] = [
            "fileId": .string(fileID),
            "fileName": .string(file.fileName),
            "kind": .string(kind.mcpValue),
            "isVideo": .bool(file.isVideo),
            "pixelSize": .string(file.pixelSize.title),
            "fileSize": .string(Int64(file.fileSize).formatted(.byteCount(style: .file))),
            "canPropose": .bool(canQueue),
            "refusals": .array(checks.filter(\.isRefusal).map { .string($0.text) }),
            "warnings": .array(checks.filter { !$0.isRefusal }.map { .string($0.text) }),
        ]
        if file.isVideo {
            if let seconds = file.seconds { object["seconds"] = .double((seconds * 100).rounded() / 100) }
            if let rate = file.frameRate { object["frameRate"] = .double((rate * 100).rounded() / 100) }
            if let codec = file.codec { object["codec"] = .string(codec) }
            object["audio"] = file.audio.isEmpty ? "none" : .array(file.audio.map { audio in
                .string("\(audio.format) · \(audio.channels) ch · \(Int(audio.sampleRate)) Hz")
            })
            if let previewFrameTimeCode { object["posterFrame"] = .string(previewFrameTimeCode) }
        }
        if let look, !look.text.isEmpty { object["textRead"] = .array(look.text.map(JSONValue.string)) }
        if let look { object["lowerPartBusyness"] = .double((look.lowerBusyness * 100).rounded() / 100) }
        return object
    }
}
