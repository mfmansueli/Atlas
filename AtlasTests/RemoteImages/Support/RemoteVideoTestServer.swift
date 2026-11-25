//
//  RemoteVideoTestServer.swift
//  AtlasTests
//

import Foundation

/// Stands in for Apple's video servers: answers each address with the
/// file it was given (a movie, a playlist or an error page) and counts the
/// downloads.
final class RemoteVideoTestServer: @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [URL: Int] = [:]
    private var files: [URL: (data: Data, type: String, status: Int)] = [:]
    /// How long each download takes.
    var delay: Duration = .zero

    func serve(_ url: URL, _ data: Data, type: String = "video/mp4", status: Int = 200) {
        lock.withLock { files[url] = (data, type, status) }
    }

    func serve(_ url: URL, playlist: String) {
        serve(url, Data(playlist.utf8), type: "application/vnd.apple.mpegurl")
    }

    func downloads(of url: URL) -> Int {
        lock.withLock { counts[url] ?? 0 }
    }

    var totalDownloads: Int {
        lock.withLock { counts.values.reduce(0, +) }
    }

    var fetch: @Sendable (URL) async throws -> (Data, URLResponse) {
        { [self] url in
            let file = lock.withLock {
                counts[url, default: 0] += 1
                return files[url]
            }
            if delay > .zero { try await Task.sleep(for: delay) }
            let answer = file ?? (Data("<html>Not Found</html>".utf8), "text/html", 404)
            let response = HTTPURLResponse(url: url, statusCode: answer.status, httpVersion: nil, headerFields: ["Content-Type": answer.type])!
            return (answer.data, response)
        }
    }

    /// Bytes that stand in for a movie: `count` of them, each its index.
    static func movie(_ count: Int) -> Data {
        Data((0..<count).map { UInt8($0 % 256) })
    }
}
