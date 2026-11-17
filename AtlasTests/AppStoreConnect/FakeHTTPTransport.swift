//
//  FakeHTTPTransport.swift
//  AtlasTests
//

import Foundation
import Synchronization
@testable import Atlas

/// Answers requests with canned responses, in order, and records them.
/// With `routes`, a request whose URL contains a route's text gets that
/// route's response instead, whatever the order (for reads sent in
/// parallel).
final class FakeHTTPTransport: HTTPTransport {
    private let state: Mutex<(responses: [CannedHTTPResponse], requests: [URLRequest])>
    private let routes: [(text: String, response: CannedHTTPResponse)]

    init(_ responses: [CannedHTTPResponse], routes: [(text: String, response: CannedHTTPResponse)] = []) {
        state = Mutex((responses, []))
        self.routes = routes
    }

    var requests: [URLRequest] { state.withLock { $0.requests } }

    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let canned = state.withLock { state -> CannedHTTPResponse? in
            state.requests.append(request)
            let address = request.url?.absoluteString.removingPercentEncoding ?? ""
            if let route = routes.first(where: { address.contains($0.text) }) { return route.response }
            return state.responses.isEmpty ? nil : state.responses.removeFirst()
        }
        guard let canned, let url = request.url else { throw URLError(.badServerResponse) }
        let response: URLResponse = if canned.isHTTP {
            HTTPURLResponse(url: url, statusCode: canned.statusCode, httpVersion: nil, headerFields: canned.headers)!
        } else {
            URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        }
        return (Data(canned.body.utf8), response)
    }
}
