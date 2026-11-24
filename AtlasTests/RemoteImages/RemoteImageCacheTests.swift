//
//  RemoteImageCacheTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Downloaded images are kept in memory and on disk: one seen before
/// comes back without the network, even after a relaunch; an error page is
/// never kept; the disk stays under its limit.
@Suite("Remote image cache")
struct RemoteImageCacheTests {
    private let directory = URL.temporaryDirectory.appending(path: "RemoteImageCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    private let shot = URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Purple211/v4/1a/2b/3c/abc/shot.png/1290x0w.png")!

    @Test func anImageIsDownloadedOnceAndReadFromDiskAfterARelaunch() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let server = RemoteImageTestServer()
        let cache = RemoteImageCache(directory: directory, fetch: server.fetch)
        let first = try await cache.data(for: shot)
        let again = try await cache.data(for: shot)
        #expect(first == again)
        #expect(server.downloads(of: shot) == 1)
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: RemoteImageCache.fileName(for: shot)).path))

        // A new launch: memory is empty, the disk still has it.
        let relaunched = RemoteImageCache(directory: directory, fetch: server.fetch)
        #expect(try await relaunched.data(for: shot) == first)
        #expect(server.downloads(of: shot) == 1)
    }

    @Test func viewsAskingAtOnceShareOneDownload() async throws {
        let server = RemoteImageTestServer()
        server.delay = .milliseconds(100)
        let cache = RemoteImageCache(directory: nil, fetch: server.fetch)
        let shot = shot
        async let first = cache.data(for: shot)
        async let second = cache.data(for: shot)
        async let third = cache.data(for: shot)
        let all = try await [first, second, third]
        #expect(Set(all).count == 1)
        #expect(server.downloads(of: shot) == 1)
    }

    @Test func anErrorPageIsNeverKept() async {
        defer { try? FileManager.default.removeItem(at: directory) }
        let server = RemoteImageTestServer()
        server.missing = [shot]
        let cache = RemoteImageCache(directory: directory, fetch: server.fetch)
        await #expect(throws: URLError.self) { try await cache.data(for: shot) }
        #expect(await cache.image(for: shot) == nil)
        // Not kept: each try asks again.
        #expect(server.downloads(of: shot) == 2)
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: RemoteImageCache.fileName(for: shot)).path))
    }

    @Test func onlyAnImageAnswerIsKeepable() {
        let url = shot
        func response(_ status: Int, _ type: String?) -> HTTPURLResponse {
            HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: type.map { ["Content-Type": $0] })!
        }
        let png = Data([1, 2, 3])
        #expect(RemoteImageCache.isKeepable(png, response: response(200, "image/png")))
        #expect(RemoteImageCache.isKeepable(png, response: response(200, "image/jpeg")))
        #expect(!RemoteImageCache.isKeepable(png, response: response(500, "image/png")))
        #expect(!RemoteImageCache.isKeepable(png, response: response(200, "text/html")))
        #expect(!RemoteImageCache.isKeepable(Data(), response: response(200, "image/png")))
    }

    @Test func imagesAreDecodedAtTheSizeAskedAndKeptForTheFirstFrame() async throws {
        let server = RemoteImageTestServer()
        let cache = RemoteImageCache(directory: nil, fetch: server.fetch)
        #expect(cache.cachedImage(for: shot, maxPixelSize: 10) == nil)
        let small = try #require(await cache.image(for: shot, maxPixelSize: 10))
        #expect(max(small.width, small.height) == 10)
        #expect(cache.cachedImage(for: shot, maxPixelSize: 10) != nil)
        // Another size is decoded anew, from the file already here.
        let full = try #require(await cache.image(for: shot))
        #expect(full.width == 40)
        #expect(server.downloads(of: shot) == 1)
        cache.forgetMemory()
        #expect(cache.cachedImage(for: shot, maxPixelSize: 10) == nil)
    }

    @Test func aFileOnThisMacIsReadAsItIsAndNotKept() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let folder = URL.temporaryDirectory.appending(path: "RemoteImageCacheTests-file-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "art.png")
        try RemoteImageTestServer.png(width: 8, height: 8).write(to: file)
        let server = RemoteImageTestServer()
        let cache = RemoteImageCache(directory: directory, fetch: server.fetch)
        #expect(await cache.image(for: file)?.width == 8)
        #expect(server.downloads(of: file) == 0)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func theDiskLosesTheLeastRecentlyUsedFirst() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let now = Date()
        for index in 0..<10 {
            let file = directory.appending(path: "file\(index)")
            try Data(repeating: 1, count: 100_000).write(to: file)
            // file0 is the oldest, file9 the newest.
            try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(Double(index) * 60)], ofItemAtPath: file.path)
        }
        let sizes = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.totalFileAllocatedSizeKey])
            .map { try $0.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize ?? 0 }
        let total = sizes.reduce(0, +)
        // Over the limit: down to 80 % of it, the oldest going first.
        let deleted = RemoteImageCache.trim(directory, limit: total / 2)
        #expect(deleted > 0)
        let left = try Set(FileManager.default.contentsOfDirectory(atPath: directory.path))
        #expect(!left.contains("file0"))
        #expect(left.contains("file9"))
        #expect(left.count == 10 - deleted)
        // Under the limit: nothing goes.
        #expect(RemoteImageCache.trim(directory, limit: total * 2) == 0)
    }

    @Test func readingAFileMarksItUsed() throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        RemoteImageCache.write(Data([1, 2, 3]), for: shot, in: directory)
        let file = directory.appending(path: RemoteImageCache.fileName(for: shot))
        try FileManager.default.setAttributes([.modificationDate: Date.distantPast], ofItemAtPath: file.path)
        #expect(RemoteImageCache.read(shot, in: directory) == Data([1, 2, 3]))
        let used = try #require(try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        #expect(used > Date().addingTimeInterval(-60))
        #expect(RemoteImageCache.fileName(for: shot).count == 64)
    }
}
