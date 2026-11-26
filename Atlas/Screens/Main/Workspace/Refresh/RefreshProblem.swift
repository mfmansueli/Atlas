//
//  RefreshProblem.swift
//  Atlas
//

import Foundation

/// Why a part of a Refresh didn't read: no network, or any other error in
/// Atlas's words (`AppleErrorCopy`, Apple's own text in its details).
enum RefreshProblem: Hashable, Sendable {
    /// The Mac has no network: "Offline · from 14:32".
    case offline
    /// Anything else: "Couldn’t update · Details…".
    case failed(AppleErrorCopy)

    /// The codes that mean this Mac has no network, rather than Apple not
    /// answering (a timeout is Apple's).
    static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff, .cannotFindHost, .dnsLookupFailed,
    ]

    /// The problem `error` stands for; nil for a read that was cancelled,
    /// which is no problem.
    static func make(for error: any Error) -> RefreshProblem? {
        if error is CancellationError { return nil }
        if let error = error as? URLError {
            if error.code == .cancelled { return nil }
            if offlineCodes.contains(error.code) { return .offline }
            if error.code == .timedOut {
                return .failed(AppleErrorCopy(
                    summary: String(localized: "App Store Connect didn’t answer in time.", comment: "kind:error · Refresh's error sheet"),
                    details: AppleErrorCopy.details(for: error)
                ))
            }
        }
        let step = AppleErrorCopy.nextStep(for: error) ?? String(localized: "Try again.", comment: "kind:error")
        return .failed(AppleErrorCopy(summary: step, details: AppleErrorCopy.details(for: error), fixTopic: HelpFixTopic(error: error)))
    }

    /// A section's error as it shows it ("Prices didn’t load. Try again in
    /// a minute." and, after a line break, "Details: HTTP 503"): the first
    /// line is the summary, the rest its details.
    static func failed(text: String) -> RefreshProblem {
        .failed(copy(fromText: text))
    }

    /// `AppleErrorCopy.text` read back: the summary, then what follows
    /// "Details:" on the next line.
    static func copy(fromText text: String) -> AppleErrorCopy {
        let lines = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let summary = lines.first.map(String.init) ?? text
        guard lines.count > 1 else { return AppleErrorCopy(summary: summary, details: nil) }
        var details = String(lines[1])
        let label = String(localized: "Details:", comment: "kind:error · before Apple's own text")
        if details.hasPrefix(label) { details = String(details.dropFirst(label.count)) }
        return AppleErrorCopy(summary: summary, details: details)
    }

    /// The problem to show when two parts failed: no network says more
    /// than an error that follows from it.
    func merged(with other: RefreshProblem?) -> RefreshProblem {
        guard let other else { return self }
        return self == .offline || other == .offline ? .offline : self
    }
}
