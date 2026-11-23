//
//  ProductPageTestRun+Requests.swift
//  Atlas
//

import Foundation

extension ProductPageTestRun {
    /// Makes one API call within the hourly budget: a used up hour is
    /// waited out first, and a 429 pauses and tries again, a few times.
    func call<Result>(_ operation: () async throws -> Result) async throws -> Result {
        var refusals = 0
        while true {
            try await waitForBudget()
            do {
                let result = try await operation()
                environment.rate.note(nil)
                return result
            } catch AppStoreConnectError.rateLimited {
                environment.rate.note(AppStoreConnectRateLimit(limit: environment.rate.rateLimit.limit, remaining: 0))
                refusals += 1
                if refusals > environment.rateLimitRetries { throw AppStoreConnectError.rateLimited }
            } catch {
                environment.rate.note(nil)
                throw error
            }
        }
    }

    private func waitForBudget() async throws {
        while environment.rate.rateLimit.remaining <= 0 {
            let resume = pausedUntil ?? environment.rate.nextHour()
            pausedUntil = resume
            while environment.now() < resume {
                try await environment.sleep(.seconds(1))
            }
            if environment.rate.rateLimit.remaining <= 0 { environment.rate.startNewHour() }
            pausedUntil = nil
        }
    }

    /// Apple said no to the request itself (not the network or the key).
    static func isRefusal(_ error: AppStoreConnectError) -> Bool {
        switch error {
        case .rejected, .forbidden: true
        default: false
        }
    }

    /// Offline, a refused key or a cancel ends the run rather than one
    /// language.
    static func stopsTheRest(_ error: any Error) -> Bool {
        if error is CancellationError { return true }
        if let error = error as? URLError { return offlineCodes.contains(error.code) }
        if let error = error as? AppStoreConnectError { return error == .unauthorized || error == .invalidPrivateKey }
        return false
    }

    /// A failure as a sentence for a row or the outcome, then `more` (what
    /// Atlas did about it). Apple's own text, if any, comes last, after
    /// "Details:".
    static func text(for error: any Error, then more: String? = nil) -> String {
        let copy = copy(for: error)
        let summary = [copy.summary, more].compactMap(\.self).filter { !$0.isEmpty }.joined(separator: " ")
        return AppleErrorCopy(summary: summary, details: copy.details).text
    }

    static func copy(for error: any Error) -> AppleErrorCopy {
        if let failure = error as? ProductPageTestFailure { return failure.copy }
        if let error = error as? URLError, offlineCodes.contains(error.code) {
            return AppleErrorCopy(summary: String(localized: "This Mac is offline."), details: nil)
        }
        if let error = error as? AppStoreConnectError, error == .unauthorized || error == .invalidPrivateKey {
            return AppleErrorCopy(summary: String(localized: "App Store Connect refused the API key."), details: nil)
        }
        return AppleErrorCopy(String(localized: "The test wasn’t pushed.", comment: "kind:error"), error: error)
    }

    /// Apple's code and detail when it sent them, e.g. "STATE_ERROR — …".
    static func describe(_ error: any Error) -> String {
        (error as? AppStoreConnectError)?.pushFailureText ?? error.localizedDescription
    }

    static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
    ]
}
