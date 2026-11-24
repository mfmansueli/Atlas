//
//  AppStoreConnectClient+ScreenshotUploads.swift
//  Atlas
//

import Foundation

extension AppStoreConnectClient {
    /// Sends one part of a reserved screenshot where its upload operation
    /// says. The URL is Apple's upload host, not the API: no token.
    func upload(_ operation: ScreenshotUploadOperation, data: Data, progress: @escaping @Sendable (Int64) -> Void) async throws {
        guard let url = URL(string: operation.url) else { throw AppStoreConnectError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = operation.method
        for header in operation.requestHeaders ?? [] {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }
        let (body, response) = try await transport.upload(request, body: operation.slice(of: data), progress: progress)
        guard let http = response as? HTTPURLResponse else { throw AppStoreConnectError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw AppStoreConnectError(statusCode: http.statusCode, body: body) }
    }
}
