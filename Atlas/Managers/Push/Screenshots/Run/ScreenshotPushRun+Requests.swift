//
//  ScreenshotPushRun+Requests.swift
//  Atlas
//

import Foundation

extension ScreenshotPushRun {
    /// Sends an API request within the hourly budget: it waits out a used
    /// up hour first, and a 429 pauses and tries again.
    func send(_ request: PushRequest) async throws -> AppStoreConnectResponse {
        try await withinBudget { try await self.environment.transport.send(request) }
    }

    func fetch(_ path: String) async throws -> AppStoreConnectResponse {
        try await withinBudget { try await self.environment.transport.fetch(path) }
    }

    private func withinBudget(_ request: () async throws -> AppStoreConnectResponse) async throws -> AppStoreConnectResponse {
        while true {
            try await waitForBudget()
            do {
                let response = try await request()
                environment.rate.note(response.rateLimit)
                return response
            } catch AppStoreConnectError.rateLimited {
                environment.rate.note(AppStoreConnectRateLimit(limit: environment.rate.rateLimit.limit, remaining: 0))
            }
        }
    }

    /// Pauses until the next hour while no requests are left. Cancel
    /// Remaining ends the wait.
    private func waitForBudget() async throws {
        while environment.rate.rateLimit.remaining <= 0 {
            let resume = pausedUntil ?? environment.rate.nextHour()
            pausedUntil = resume
            while environment.now() < resume {
                if isCancelling { throw CancellationError() }
                try await environment.sleep(.seconds(1))
            }
            if environment.rate.rateLimit.remaining <= 0 { environment.rate.startNewHour() }
            pausedUntil = nil
        }
    }

    /// The row status for an error. Offline and a refused key stop the
    /// rest of the push.
    func status(for error: any Error, replaces: Bool) -> ScreenshotUploadStatus {
        switch error {
        case let failure as ScreenshotPushFailure:
            return .failed(failure.text(replaces: replaces))
        case is CancellationError:
            return .cancelled
        case let error as AppStoreConnectError:
            if error == .unauthorized || error == .invalidPrivateKey { stopReason = String(localized: "Not sent · the API key was refused") }
            return .failed(Self.notPushed(error, replaces: replaces))
        case let error as URLError where Self.offlineCodes.contains(error.code):
            stopReason = String(localized: "Not sent · offline")
            return .notSent(String(localized: "Not sent · offline"))
        default:
            return .failed(Self.notPushed(error, replaces: replaces))
        }
    }

    /// A row's whole message for an error that isn't Atlas's own: what
    /// happened, what stays, then Apple's text after "Details:".
    static func notPushed(_ error: any Error, replaces: Bool) -> String {
        let copy = AppleErrorCopy(String(localized: "The image wasn’t pushed.", comment: "kind:error"), error: error)
        let summary = ScreenshotPushFailure.request(detail: copy.summary).text(replaces: replaces)
        return AppleErrorCopy(summary: summary, details: copy.details).text
    }

    /// An error as one short sentence ending in a period.
    static func describe(_ error: any Error) -> String {
        let text = (error as? AppStoreConnectError)?.pushFailureText ?? error.localizedDescription
        return text.hasSuffix(".") ? text : text + "."
    }

    static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
    ]
}
