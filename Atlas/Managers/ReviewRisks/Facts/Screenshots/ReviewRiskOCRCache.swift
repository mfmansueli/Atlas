//
//  ReviewRiskOCRCache.swift
//  Atlas
//

import Foundation

/// What Vision read in live screenshots, one small JSON file per image and
/// language in Application Support/Atlas/ReviewRisks/ocr, named by the
/// screenshot's checksum: a refresh reads only the images that changed.
/// Unit tests and DEBUG scenes keep nothing.
struct ReviewRiskOCRCache: Sendable {
    /// Bumped when what's kept changes, so old readings are read again.
    static let version = 1

    let directory: URL?

    static var shared: ReviewRiskOCRCache {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return ReviewRiskOCRCache(directory: nil) }
        #endif
        return ReviewRiskOCRCache(directory: URL.applicationSupportDirectory.appending(path: "Atlas/ReviewRisks/ocr"))
    }

    /// "<checksum>-de-DE-v1": the file name for an image read in a
    /// language; nil without a checksum or an ID to name it by.
    static func key(checksum: String?, screenshotID: String, locale: String) -> String? {
        let base = checksum.flatMap { $0.isEmpty ? nil : $0 } ?? (screenshotID.isEmpty ? nil : "id-\(screenshotID)")
        guard let base else { return nil }
        let raw = "\(base)-\(locale)-v\(version)"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return String(raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    }

    func reading(for key: String) -> ReviewRiskScreenshotReading? {
        guard let directory, let data = try? Data(contentsOf: file(key, in: directory)) else { return nil }
        return try? JSONDecoder().decode(ReviewRiskScreenshotReading.self, from: data)
    }

    func keep(_ reading: ReviewRiskScreenshotReading, for key: String) {
        guard let directory, let data = try? JSONEncoder().encode(reading) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: file(key, in: directory), options: .atomic)
    }

    private func file(_ key: String, in directory: URL) -> URL {
        directory.appending(path: "\(key).json")
    }
}
