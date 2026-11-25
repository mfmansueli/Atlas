//
//  RemoteVideoCacheTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// An In-App Event's clip is downloaded once, kept on disk as one movie
/// (a stream joined), and played from there wherever it shows; views
/// asking at once share the download; an error page is never kept.
@Suite("Remote video cache")
struct RemoteVideoCacheTests {
    private let directory = URL.temporaryDirectory.appending(path: "RemoteVideoCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    private let clip = URL(string: "https://apptrailers.itunes.apple.com/itunes-assets/PurpleVideo221/v4/ab/cd/clip/card.mp4")!
    private let stream = URL(string: "https://apptrailers.itunes.apple.com/itunes-assets/PurpleVideo221/v4/ab/cd/clip/P1_default.m3u8")!

    @Test func aMovieIsDownloadedOnceAndReadFromDiskAfterARelaunch() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let server = RemoteVideoTestServer()
        server.serve(clip, RemoteVideoTestServer.movie(300))
        let cache = RemoteVideoCache(directory: directory, fetch: server.fetch)
        #expect(cache.cachedFile(for: clip) == nil)
        let file = try await cache.file(for: clip)
        #expect(try Data(contentsOf: file) == RemoteVideoTestServer.movie(300))
        #expect(file.lastPathComponent == RemoteVideoCache.fileName(for: clip))
        // Now known for the next view's first frame.
        #expect(cache.cachedFile(for: clip) == file)
        #expect(try await cache.file(for: clip) == file)
        #expect(server.downloads(of: clip) == 1)

        // A new launch: memory is empty, the disk still has it.
        let relaunched = RemoteVideoCache(directory: directory, fetch: server.fetch)
        #expect(relaunched.cachedFile(for: clip) == nil)
        #expect(try await relaunched.file(for: clip) == file)
        #expect(server.downloads(of: clip) == 1)
    }

    @Test func viewsAskingAtOnceShareOneDownload() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let server = RemoteVideoTestServer()
        server.delay = .milliseconds(100)
        server.serve(clip, RemoteVideoTestServer.movie(64))
        let cache = RemoteVideoCache(directory: directory, fetch: server.fetch)
        let clip = clip
        async let card = cache.file(for: clip)
        async let page = cache.file(for: clip)
        async let viewer = cache.file(for: clip)
        let files = try await [card, page, viewer]
        #expect(Set(files).count == 1)
        #expect(server.downloads(of: clip) == 1)
    }

    @Test func aStreamIsJoinedIntoOneMovieAtTheVersionThatFits() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let folder = stream.deletingLastPathComponent()
        let small = folder.appending(path: "video_640x360.m3u8"), large = folder.appending(path: "video_1920x1080.m3u8")
        let movie = folder.appending(path: "video_1920x1080-.mp4")
        let server = RemoteVideoTestServer()
        server.serve(stream, playlist: """
        #EXTM3U
        #EXT-X-STREAM-INF:BANDWIDTH=561836,RESOLUTION=640x360
        video_640x360.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=2440692,RESOLUTION=1920x1080
        video_1920x1080.m3u8
        """)
        server.serve(large, playlist: """
        #EXTM3U
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXT-X-MAP:URI="video_1920x1080-.mp4",BYTERANGE="10@0"
        #EXTINF:6.0,
        #EXT-X-BYTERANGE:30@10
        video_1920x1080-.mp4
        #EXTINF:5.8,
        #EXT-X-BYTERANGE:60@40
        video_1920x1080-.mp4
        #EXT-X-ENDLIST
        """)
        server.serve(movie, RemoteVideoTestServer.movie(100))
        let cache = RemoteVideoCache(directory: directory, maxSide: 1920, fetch: server.fetch)
        let file = try await cache.file(for: stream)
        #expect(try Data(contentsOf: file) == RemoteVideoTestServer.movie(100))
        // The playlists once, the movie once, the smaller version never.
        #expect(server.downloads(of: stream) == 1)
        #expect(server.downloads(of: large) == 1)
        #expect(server.downloads(of: movie) == 1)
        #expect(server.downloads(of: small) == 0)
    }

    @Test func piecesInTheirOwnFilesAreJoinedInOrder() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let folder = stream.deletingLastPathComponent()
        let server = RemoteVideoTestServer()
        server.serve(stream, playlist: """
        #EXTM3U
        #EXT-X-MAP:URI="init.mp4"
        #EXTINF:6.0,
        one.m4s
        #EXTINF:6.0,
        two.m4s
        """)
        server.serve(folder.appending(path: "init.mp4"), Data([1, 2]))
        server.serve(folder.appending(path: "one.m4s"), Data([3, 4, 5]))
        server.serve(folder.appending(path: "two.m4s"), Data([6]))
        let cache = RemoteVideoCache(directory: directory, fetch: server.fetch)
        let file = try await cache.file(for: stream)
        #expect(try Data(contentsOf: file) == Data([1, 2, 3, 4, 5, 6]))
    }

    @Test func aStreamThatDoesntJoinIsRefusedAndNotKept() async {
        defer { try? FileManager.default.removeItem(at: directory) }
        let server = RemoteVideoTestServer()
        // MPEG-TS pieces: no header to join them into an MP4.
        server.serve(stream, playlist: """
        #EXTM3U
        #EXTINF:6.0,
        one.ts
        """)
        let cache = RemoteVideoCache(directory: directory, fetch: server.fetch)
        await #expect(throws: URLError.self) { try await cache.file(for: stream) }
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: RemoteVideoCache.fileName(for: stream)).path))
    }

    @Test func anErrorPageIsNeverKept() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let server = RemoteVideoTestServer()
        let html = try #require(URL(string: "https://example.com/clip.mp4"))
        server.serve(html, Data("<html>Sign in</html>".utf8), type: "text/html")
        let cache = RemoteVideoCache(directory: directory, fetch: server.fetch)
        // Not served: a 404.
        await #expect(throws: URLError.self) { try await cache.file(for: clip) }
        await #expect(throws: URLError.self) { try await cache.file(for: html) }
        // Not kept: each try asks again.
        await #expect(throws: URLError.self) { try await cache.file(for: clip) }
        #expect(server.downloads(of: clip) == 2)
        #expect(cache.cachedFile(for: clip) == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: RemoteVideoCache.fileName(for: clip)).path))
    }

    @Test func aClipIsKeptByItsAddressWithoutTheQuery() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        var signed = try #require(URLComponents(url: clip, resolvingAgainstBaseURL: false))
        signed.queryItems = [URLQueryItem(name: "token", value: "abc")]
        let withQuery = try #require(signed.url)
        let other = clip.deletingLastPathComponent().appending(path: "details.mp4")
        #expect(RemoteVideoCache.key(for: withQuery) == clip.absoluteString)
        #expect(RemoteVideoCache.fileName(for: withQuery) == RemoteVideoCache.fileName(for: clip))
        #expect(RemoteVideoCache.fileName(for: other) != RemoteVideoCache.fileName(for: clip))
        #expect(RemoteVideoCache.fileName(for: clip).count == 64 + ".mp4".count)
        #expect(RemoteVideoCache.fileName(for: clip).hasSuffix(".mp4"))

        let server = RemoteVideoTestServer()
        server.serve(clip, RemoteVideoTestServer.movie(10))
        server.serve(withQuery, RemoteVideoTestServer.movie(10))
        let cache = RemoteVideoCache(directory: directory, fetch: server.fetch)
        let first = try await cache.file(for: clip)
        #expect(cache.cachedFile(for: withQuery) == first)
        #expect(try await cache.file(for: withQuery) == first)
        #expect(server.totalDownloads == 1)
    }

    @Test func forgettingOrLosingTheFileIsAMiss() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let server = RemoteVideoTestServer()
        server.serve(clip, RemoteVideoTestServer.movie(10))
        let cache = RemoteVideoCache(directory: directory, fetch: server.fetch)
        let file = try await cache.file(for: clip)
        cache.forgetMemory()
        #expect(cache.cachedFile(for: clip) == nil)
        // Still on disk: read without the network.
        #expect(try await cache.file(for: clip) == file)
        #expect(server.downloads(of: clip) == 1)
        // Cleared (Clear Caches, or trimmed): downloaded again.
        try FileManager.default.removeItem(at: file)
        #expect(cache.cachedFile(for: clip) == nil)
        #expect(try await cache.file(for: clip) == file)
        #expect(server.downloads(of: clip) == 2)
    }

    @Test func aFileOnThisMacIsPlayedAsItIs() async throws {
        let server = RemoteVideoTestServer()
        let cache = RemoteVideoCache(directory: directory, fetch: server.fetch)
        let local = URL(fileURLWithPath: "/tmp/EventArtwork/card.mov")
        #expect(try await cache.file(for: local) == local)
        #expect(cache.cachedFile(for: local) == local)
        #expect(server.totalDownloads == 0)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func onlyAMovieOrAPlaylistIsTaken() throws {
        func response(_ type: String) throws -> HTTPURLResponse {
            try #require(HTTPURLResponse(url: clip, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": type]))
        }
        let mp4 = try response("video/mp4"), mov = try response("video/quicktime"), bytes = try response("application/octet-stream")
        let html = try response("text/html"), playlist = try response("application/vnd.apple.mpegurl")
        #expect(RemoteVideoCache.isMovie(mp4))
        #expect(RemoteVideoCache.isMovie(mov))
        #expect(RemoteVideoCache.isMovie(bytes))
        #expect(!RemoteVideoCache.isMovie(html))
        #expect(RemoteVideoCache.isPlaylist(Data(), response: playlist))
        #expect(RemoteVideoCache.isPlaylist(Data("#EXTM3U\n".utf8), response: bytes))
        #expect(!RemoteVideoCache.isPlaylist(Data("<html>".utf8), response: html))
    }
}
