//
//  LiveReviewRiskURLProbe.swift
//  Atlas
//

import Foundation

/// The live probe: HEAD, then GET when HEAD isn't allowed (405/403/501),
/// 10 seconds each, through an ephemeral session.
struct LiveReviewRiskURLProbe: ReviewRiskURLProbing {
    func probe(_ url: URL) async -> ReviewRiskURLStatus {
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        let head = await send(url, method: "HEAD", session: session)
        if case let .httpError(code) = head, [403, 405, 501].contains(code) {
            return await send(url, method: "GET", session: session)
        }
        return head
    }

    private func send(_ url: URL, method: String, session: URLSession) async -> ReviewRiskURLStatus {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = method
        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .opens }
            return (200..<400).contains(http.statusCode) ? .opens : .httpError(http.statusCode)
        } catch {
            return .unreachable(error.localizedDescription)
        }
    }
}
