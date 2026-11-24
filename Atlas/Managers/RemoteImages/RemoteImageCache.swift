//
//  RemoteImageCache.swift
//  Atlas
//

import CoreGraphics
import CryptoKit
import Foundation
import ImageIO

/// Every image Atlas downloads (app icons, App Store screenshots, artwork,
/// Asset Library files), kept in memory and on disk, so one seen before
/// shows at once, even after a relaunch, without asking the network.
///
/// Kept by address, which is safe because Apple's image addresses name the
/// file's content (`…/v4/1a/2b/…/hash/name.png/1290x0w.png`): an image
/// that changes on the App Store gets a new address and is downloaded
/// anew; one that didn't is read from here. On disk in
/// `Caches/Atlas/RemoteImages` (Settings → Privacy & Data counts and
/// clears it), at most `diskLimit` bytes, the least recently used going
/// first. Several views asking for one image share one download.
actor RemoteImageCache {
    static let shared = RemoteImageCache(directory: RemoteImageCache.defaultDirectory)

    /// Nil keeps images in memory only (DEBUG scenes and the tests' host).
    let directory: URL?
    let diskLimit: Int
    private let fetch: @Sendable (URL) async throws -> (Data, URLResponse)
    private var loads: [URL: Task<Data, any Error>] = [:]
    /// Bytes written since the disk was last trimmed.
    private var writtenSinceTrim = 0

    /// The downloaded files, by address; the system empties it under
    /// memory pressure. `NSCache` is thread-safe (Apple's documentation),
    /// so both are read outside the actor, for a view's first frame.
    private nonisolated(unsafe) let memory: NSCache<NSURL, NSData> = {
        let cache = NSCache<NSURL, NSData>()
        cache.totalCostLimit = 150 * 1024 * 1024
        return cache
    }()

    /// Decoded images, by address and size, for views that draw them
    /// straight away.
    private nonisolated(unsafe) let decoded: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.totalCostLimit = 200 * 1024 * 1024
        return cache
    }()

    init(
        directory: URL?,
        diskLimit: Int = 500 * 1024 * 1024,
        fetch: @escaping @Sendable (URL) async throws -> (Data, URLResponse) = { try await URLSession.shared.data(from: $0) }
    ) {
        self.directory = directory
        self.diskLimit = diskLimit
        self.fetch = fetch
    }

    static var defaultDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return URL.cachesDirectory.appending(path: "Atlas/RemoteImages", directoryHint: .isDirectory)
    }

    // MARK: - Reading

    /// The file at `url`: from memory, from disk, or downloaded and kept.
    /// A file on this Mac is read as it is, never kept. Throws when the
    /// download fails or isn't a file (an error page is never kept).
    func data(for url: URL) async throws -> Data {
        if url.isFileURL {
            return try await Task.detached(priority: .utility) { try Data(contentsOf: url) }.value
        }
        if let kept = memory.object(forKey: url as NSURL) { return kept as Data }
        if let load = loads[url] { return try await load.value }
        let load = Task.detached(priority: .utility) { [directory, fetch] in
            if let directory, let kept = Self.read(url, in: directory) { return kept }
            let (data, response) = try await fetch(url)
            guard Self.isKeepable(data, response: response) else { throw URLError(.badServerResponse) }
            if let directory { Self.write(data, for: url, in: directory) }
            return data
        }
        loads[url] = load
        defer { loads[url] = nil }
        let data = try await load.value
        memory.setObject(data as NSData, forKey: url as NSURL, cost: data.count)
        if directory != nil { noteWritten(data.count) }
        return data
    }

    /// The image at `url`, decoded at most `maxPixelSize` on its longest
    /// side (nil: as it is); nil when it can't be had.
    func image(for url: URL, maxPixelSize: Int? = nil) async -> CGImage? {
        if let image = cachedImage(for: url, maxPixelSize: maxPixelSize) { return image }
        guard let data = try? await data(for: url) else { return nil }
        let image = await Task.detached(priority: .utility) { Self.decode(data, maxPixelSize: maxPixelSize) }.value
        if let image, !url.isFileURL {
            decoded.setObject(image, forKey: Self.decodedKey(url, maxPixelSize), cost: image.bytesPerRow * image.height)
        }
        return image
    }

    /// The decoded image if it was drawn before in this launch, for a view's
    /// first frame.
    nonisolated func cachedImage(for url: URL, maxPixelSize: Int? = nil) -> CGImage? {
        decoded.object(forKey: Self.decodedKey(url, maxPixelSize))
    }

    /// Forgets what's in memory; Clear Caches deletes the disk's.
    nonisolated func forgetMemory() {
        memory.removeAllObjects()
        decoded.removeAllObjects()
    }

    // MARK: - Disk

    /// A file name for an address: its SHA-256, so any address fits.
    nonisolated static func fileName(for url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func read(_ url: URL, in directory: URL) -> Data? {
        let file = directory.appending(path: fileName(for: url))
        guard let data = try? Data(contentsOf: file), !data.isEmpty else { return nil }
        // Used now: the last to go when the disk is trimmed.
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
        return data
    }

    nonisolated static func write(_ data: Data, for url: URL, in directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appending(path: fileName(for: url)), options: .atomic)
    }

    /// A downloaded answer worth keeping: a 2xx with a body, and an image
    /// when the server says what it is.
    nonisolated static func isKeepable(_ data: Data, response: URLResponse) -> Bool {
        guard !data.isEmpty else { return false }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return false }
        guard let type = response.mimeType else { return true }
        return type.hasPrefix("image/") || type == "application/octet-stream"
    }

    /// Deletes the least recently used files until the folder is under
    /// `limit` × 0.8; returns how many it deleted.
    @discardableResult
    nonisolated static func trim(_ directory: URL, limit: Int) -> Int {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .totalFileAllocatedSizeKey, .isRegularFileKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys)) else { return 0 }
        var files: [(url: URL, date: Date, size: Int)] = urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { return nil }
            return (url, values.contentModificationDate ?? .distantPast, values.totalFileAllocatedSize ?? 0)
        }
        var total = files.reduce(0) { $0 + $1.size }
        guard total > limit else { return 0 }
        files.sort { $0.date < $1.date }
        var deleted = 0
        for file in files where total > limit * 8 / 10 {
            try? FileManager.default.removeItem(at: file.url)
            total -= file.size
            deleted += 1
        }
        return deleted
    }

    /// Trims the disk once every tenth of the limit written.
    private func noteWritten(_ bytes: Int) {
        writtenSinceTrim += bytes
        guard let directory, writtenSinceTrim > diskLimit / 10 else { return }
        writtenSinceTrim = 0
        let limit = diskLimit
        Task.detached(priority: .background) { Self.trim(directory, limit: limit) }
    }

    // MARK: - Decoding

    nonisolated static func decode(_ data: Data, maxPixelSize: Int?) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let maxPixelSize else { return CGImageSourceCreateImageAtIndex(source, 0, nil) }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private nonisolated static func decodedKey(_ url: URL, _ maxPixelSize: Int?) -> NSString {
        "\(maxPixelSize ?? 0)|\(url.absoluteString)" as NSString
    }
}
