//
//  RemoteVideoCache.swift
//  Atlas
//

import CryptoKit
import Foundation

/// The moving artwork Atlas downloads (the clips App Store Connect streams
/// for an In-App Event's card and details page), kept on disk as one movie
/// file each, so `AVPlayer` plays it from this Mac and a clip is
/// downloaded once wherever it shows: the gallery, the event page, the
/// Artwork panel, the viewer and the App Store preview's event card.
/// `RemoteImageCache` keeps their poster frames.
///
/// A stream (an HLS playlist) is joined into a movie at the largest
/// version no longer than `maxSide` (`HLSMovieAssembler`); a plain movie
/// address is kept as it is. Kept by address without its query: Apple's
/// asset addresses name the content, so a clip that changes gets a new
/// one. In `Caches/Atlas/RemoteVideos` (Settings → Privacy & Data counts
/// and clears it), at most `diskLimit` bytes, the least recently used
/// going first. Several views asking for one clip share one download.
actor RemoteVideoCache {
    static let shared = RemoteVideoCache(directory: RemoteVideoCache.defaultDirectory)

    let directory: URL
    let diskLimit: Int
    /// The longest side of the version of a stream that's kept.
    let maxSide: Int
    private let fetch: @Sendable (URL) async throws -> (Data, URLResponse)
    private var loads: [String: Task<(file: URL, written: Int), any Error>] = [:]
    /// Bytes written since the disk was last trimmed.
    private var writtenSinceTrim = 0

    /// The movies found or written in this launch, by key, so a view's
    /// first frame plays one without waiting. `NSCache` is thread-safe.
    private nonisolated(unsafe) let known = NSCache<NSString, NSURL>()

    init(
        directory: URL,
        diskLimit: Int = 500 * 1024 * 1024,
        maxSide: Int = 1920,
        fetch: @escaping @Sendable (URL) async throws -> (Data, URLResponse) = { try await URLSession.shared.data(from: $0) }
    ) {
        self.directory = directory
        self.diskLimit = diskLimit
        self.maxSide = maxSide
        self.fetch = fetch
    }

    /// DEBUG scenes and the tests' host keep movies in a temporary folder,
    /// away from the person's caches.
    static var defaultDirectory: URL {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil {
            return URL.temporaryDirectory.appending(path: "Atlas-RemoteVideos", directoryHint: .isDirectory)
        }
        #endif
        return URL.cachesDirectory.appending(path: "Atlas/RemoteVideos", directoryHint: .isDirectory)
    }

    // MARK: - Reading

    /// The movie at `url` as a file on this Mac: kept before, or
    /// downloaded (a stream joined into one movie) and kept. A file on this
    /// Mac is played as it is. Throws when the download fails or isn't a
    /// movie (an error page is never kept).
    func file(for url: URL) async throws -> URL {
        if url.isFileURL { return url }
        if let kept = cachedFile(for: url) { return kept }
        let key = Self.key(for: url)
        if let load = loads[key] { return try await load.value.file }
        let load = Task.detached(priority: .utility) { [directory, fetch, maxSide] in
            let file = directory.appending(path: Self.fileName(for: url))
            if Self.touch(file) { return (file: file, written: 0) }
            let movie = try await Self.download(url, maxSide: maxSide, fetch: fetch)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try movie.write(to: file, options: .atomic)
            return (file: file, written: movie.count)
        }
        loads[key] = load
        defer { loads[key] = nil }
        let loaded = try await load.value
        known.setObject(loaded.file as NSURL, forKey: key as NSString)
        noteWritten(loaded.written)
        return loaded.file
    }

    /// The movie if it was found or downloaded before in this launch and
    /// is still on disk, for a view's first frame.
    nonisolated func cachedFile(for url: URL) -> URL? {
        if url.isFileURL { return url }
        let key = Self.key(for: url) as NSString
        guard let file = known.object(forKey: key) as URL? else { return nil }
        guard FileManager.default.fileExists(atPath: file.path) else {
            known.removeObject(forKey: key)
            return nil
        }
        return file
    }

    /// Forgets what this launch found; Clear Caches deletes the disk's.
    nonisolated func forgetMemory() {
        known.removeAllObjects()
    }

    // MARK: - Keys

    /// What a clip is kept by: its address without query or fragment.
    nonisolated static func key(for url: URL) -> String {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return url.absoluteString }
        parts.query = nil
        parts.fragment = nil
        return parts.string ?? url.absoluteString
    }

    /// A file name for an address: the SHA-256 of its key, as a movie.
    nonisolated static func fileName(for url: URL) -> String {
        SHA256.hash(data: Data(key(for: url).utf8)).map { String(format: "%02x", $0) }.joined() + ".mp4"
    }

    // MARK: - Downloading

    /// The movie's bytes: a plain movie as it came, a stream joined.
    nonisolated static func download(
        _ url: URL, maxSide: Int, fetch: @escaping @Sendable (URL) async throws -> (Data, URLResponse)
    ) async throws -> Data {
        let (data, response) = try await fetch(url)
        try check(data, response)
        if isPlaylist(data, response: response) {
            return try await HLSMovieAssembler.movie(playlist: data, at: response.url ?? url, maxSide: maxSide) { part in
                let (data, response) = try await fetch(part)
                try Self.check(data, response)
                return data
            }
        }
        guard isMovie(response) else { throw URLError(.cannotDecodeContentData) }
        return data
    }

    /// A 2xx with a body.
    nonisolated static func check(_ data: Data, _ response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw URLError(.badServerResponse) }
        if data.isEmpty { throw URLError(.zeroByteResource) }
    }

    /// An HLS playlist, by its type or its first line.
    nonisolated static func isPlaylist(_ data: Data, response: URLResponse) -> Bool {
        if response.mimeType?.lowercased().contains("mpegurl") == true { return true }
        return data.starts(with: Data("#EXTM3U".utf8))
    }

    /// A movie when the server says what it is (not an error page).
    nonisolated static func isMovie(_ response: URLResponse) -> Bool {
        guard let type = response.mimeType?.lowercased() else { return true }
        return type.hasPrefix("video/") || type == "application/mp4" || type == "application/octet-stream"
    }

    // MARK: - Disk

    /// Marks `file` used now (the last to go when the disk is trimmed);
    /// false when it isn't there.
    nonisolated static func touch(_ file: URL) -> Bool {
        guard let size = (try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, size > 0 else { return false }
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
        return true
    }

    /// Trims the disk once every tenth of the limit written.
    private func noteWritten(_ bytes: Int) {
        guard bytes > 0 else { return }
        writtenSinceTrim += bytes
        guard writtenSinceTrim > diskLimit / 10 else { return }
        writtenSinceTrim = 0
        let directory = directory, limit = diskLimit
        Task.detached(priority: .background) { RemoteImageCache.trim(directory, limit: limit) }
    }
}
