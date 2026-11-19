//
//  InAppEventArtworkFiles.swift
//  Atlas
//

import Foundation

/// Where event cards and details pages wait until a push uploads them:
/// Atlas's own container (the sandbox can't read a path an
/// assistant names), as `<appID>/<file ID>/<file name>`, so Apple gets the
/// file's own name. Files arrive from `render_event_artwork` (a rendered
/// page, or an image in base64) or the upload link. Beside each one,
/// `.atlas-info.json` keeps the name it came with, its SHA-256 and where it
/// came from (`InAppEventArtworkFileInfo`); older files have none.
enum InAppEventArtworkFiles {
    static let directory = URL.applicationSupportDirectory.appending(path: "Atlas/EventArtwork", directoryHint: .isDirectory)

    /// This launch's upload token, part of the link `get_in_app_events`
    /// gives.
    static let uploadToken = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()

    /// The info file beside each file; its dot keeps it out of `url(id:)`.
    static let infoName = ".atlas-info.json"

    /// Writes `data`, with its info, and returns its file ID
    /// ("ea-1f3c9a0b2d").
    static func save(
        _ data: Data, fileName: String?, appID: StoreApp.ID, in directory: URL = directory, origin: InAppEventArtworkOrigin? = nil,
        now: Date = .now
    ) throws -> String {
        let id = "ea-" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10).lowercased()
        let folder = folder(id: id, appID: appID, in: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: folder.appending(path: name(fileName, for: data)), options: .atomic)
        let given = fileName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let info = InAppEventArtworkFileInfo(
            originalName: given?.isEmpty == false ? given : nil, sha256: InAppEventArtworkFileInfo.sha256(of: data), origin: origin, savedAt: now
        )
        try? write(info, to: folder)
        return id
    }

    /// The file `id` is, if it's still here.
    static func url(id: String, appID: StoreApp.ID, in directory: URL = directory) -> URL? {
        guard isFileID(id) else { return nil }
        let files = (try? FileManager.default.contentsOfDirectory(at: folder(id: id, appID: appID, in: directory), includingPropertiesForKeys: nil)) ?? []
        return files.first { !$0.lastPathComponent.hasPrefix(".") }
    }

    /// The info kept beside the file at `path`; nil for a file kept before
    /// Atlas wrote one, or one that's gone.
    static func info(atPath path: String) -> InAppEventArtworkFileInfo? {
        let folder = URL(fileURLWithPath: path).deletingLastPathComponent()
        guard let data = try? Data(contentsOf: folder.appending(path: infoName)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(InAppEventArtworkFileInfo.self, from: data)
    }

    /// The infos of the files at `paths`, by path; a file without one is
    /// left out.
    static func infos(atPaths paths: some Sequence<String>) -> [String: InAppEventArtworkFileInfo] {
        var infos: [String: InAppEventArtworkFileInfo] = [:]
        for path in Set(paths) {
            infos[path] = info(atPath: path)
        }
        return infos
    }

    /// The info of the file `id`.
    static func info(id: String, appID: StoreApp.ID, in directory: URL = directory) -> InAppEventArtworkFileInfo? {
        url(id: id, appID: appID, in: directory).flatMap { info(atPath: $0.path(percentEncoded: false)) }
    }

    /// Marks the files `ids` as the Make the Artwork concept `conceptID`
    /// (`title`). A file kept before Atlas wrote its info gets one now.
    static func markConcept(
        _ ids: [String], conceptID: String, title: String, appID: StoreApp.ID, in directory: URL = directory, now: Date = .now
    ) {
        for id in Set(ids) {
            guard let url = url(id: id, appID: appID, in: directory) else { continue }
            var info = info(atPath: url.path(percentEncoded: false))
            if info == nil, let data = try? Data(contentsOf: url) {
                info = InAppEventArtworkFileInfo(sha256: InAppEventArtworkFileInfo.sha256(of: data), savedAt: now)
            }
            guard var marked = info else { continue }
            var origin = marked.origin ?? InAppEventArtworkOrigin(source: .page, name: url.lastPathComponent)
            origin.conceptID = conceptID
            origin.conceptTitle = title
            marked.origin = origin
            try? write(marked, to: url.deletingLastPathComponent())
        }
    }

    /// Every file kept for `appID`, with its name, size and info.
    static func stored(appID: StoreApp.ID, in directory: URL = directory) -> [InAppEventArtworkStoredFile] {
        let app = directory.appending(path: safe(appID), directoryHint: .isDirectory)
        let folders = (try? FileManager.default.contentsOfDirectory(at: app, includingPropertiesForKeys: nil)) ?? []
        return folders.compactMap { folder in
            let id = folder.lastPathComponent
            guard isFileID(id), let url = url(id: id, appID: appID, in: directory) else { return nil }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return InAppEventArtworkStoredFile(
                fileID: id, url: url, fileName: url.lastPathComponent, fileSize: size, info: info(atPath: url.path(percentEncoded: false))
            )
        }
    }

    private static func folder(id: String, appID: StoreApp.ID, in directory: URL) -> URL {
        directory.appending(path: safe(appID), directoryHint: .isDirectory).appending(path: id, directoryHint: .isDirectory)
    }

    private static func write(_ info: InAppEventArtworkFileInfo, to folder: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(info).write(to: folder.appending(path: infoName), options: .atomic)
    }

    /// "gratitude-week-2026-card-en-us.png", for a page Atlas
    /// rendered.
    static func renderedName(event: String, kind: InAppEventMedia.Kind, locale: String) -> String {
        let slug = RetentionImageFiles.slug("\(event) \(kind.mcpValue) \(locale)")
        return "\(slug == "retention-image" ? "event-\(kind.mcpValue)" : slug).png"
    }

    static func isFileID(_ id: String) -> Bool {
        id.hasPrefix("ea-") && id.count == 13 && id.dropFirst(3).allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    /// A name Apple and the file system both take, with the extension the
    /// bytes have when the name gives none: "Gratitude card.png".
    static func name(_ proposed: String?, for data: Data) -> String {
        let last = proposed.map { URL(fileURLWithPath: $0).lastPathComponent } ?? ""
        let cleaned = last.replacingOccurrences(of: ":", with: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        let stem = cleaned.isEmpty || cleaned.hasPrefix(".") ? "event-artwork" : String(cleaned.prefix(120))
        guard URL(fileURLWithPath: stem).pathExtension.isEmpty, let sniffed = sniffedExtension(data) else { return stem }
        return "\(stem).\(sniffed)"
    }

    /// "png", "jpg", "mov" or "mp4" from the file's first bytes.
    static func sniffedExtension(_ data: Data) -> String? {
        let bytes = [UInt8](data.prefix(12))
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "png" }
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "jpg" }
        guard bytes.count >= 12, bytes[4...7].elementsEqual(Array("ftyp".utf8)) else { return nil }
        return bytes[8...11].elementsEqual(Array("qt  ".utf8)) ? "mov" : "mp4"
    }

    private static func safe(_ component: String) -> String {
        let cleaned = component.filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
        return cleaned.isEmpty || cleaned.allSatisfy { $0 == "." } ? "app" : cleaned
    }
}
