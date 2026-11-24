//
//  RemoteImageTestServer.swift
//  AtlasTests
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Stands in for Apple's image servers: answers each address with a PNG
/// (or an error page) and counts the downloads.
final class RemoteImageTestServer: @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [URL: Int] = [:]
    /// Addresses answered with a 404 HTML page.
    var missing: Set<URL> = []
    /// How long each download takes.
    var delay: Duration = .zero

    func downloads(of url: URL) -> Int {
        lock.withLock { counts[url] ?? 0 }
    }

    var fetch: @Sendable (URL) async throws -> (Data, URLResponse) {
        { [self] url in
            lock.withLock { counts[url, default: 0] += 1 }
            if delay > .zero { try await Task.sleep(for: delay) }
            if missing.contains(url) {
                let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: ["Content-Type": "text/html"])!
                return (Data("<html>Not Found</html>".utf8), response)
            }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/png"])!
            return (Self.png(width: 40, height: 20), response)
        }
    }

    /// A plain PNG of that size.
    static func png(width: Int, height: Int) -> Data {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 0.4, green: 0.3, blue: 0.9, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}
