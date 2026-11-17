//
//  InAppEventArtworkFiles.swift
//  Atlas
//

import Foundation

/// Where event cards and details pages wait until a push uploads them:
/// Atlas's own container (the sandbox can't read a path an
/// assistant names), as `<appID>/<file ID>/<file name>`, so Apple gets the
/// file's own name. Files arrive from `render_event_artwork` (a rendered
/// page, or an image in base64) or the upload link.
enum InAppEventArtworkFiles {
    static let directory = URL.applicationSupportDirectory.appending(path: "Atlas/EventArtwork", directoryHint: .isDirectory)

    /// This launch's upload token, part of the link `get_in_app_events`
    /// gives.
    static let uploadToken = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()

    /// Writes `data` and returns its file ID ("ea-1f3c9a0b2d").
    static func save(_ data: Data, fileName: String?, appID: StoreApp.ID, in directory: URL = directory) throws -> String {
        let id = "ea-" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(10).lowercased()
        let folder = directory.appending(path: safe(appID), directoryHint: .isDirectory).appending(path: id, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: folder.appending(path: name(fileName, for: data)), options: .atomic)
        return id
    }

    /// The file `id` is, if it's still here.
    static func url(id: String, appID: StoreApp.ID, in directory: URL = directory) -> URL? {
        guard isFileID(id) else { return nil }
        let folder = directory.appending(path: safe(appID), directoryHint: .isDirectory).appending(path: id, directoryHint: .isDirectory)
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.first { !$0.lastPathComponent.hasPrefix(".") }
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
