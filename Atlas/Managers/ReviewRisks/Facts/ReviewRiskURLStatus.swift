//
//  ReviewRiskURLStatus.swift
//  Atlas
//

import Foundation

/// What happened when Atlas opened a URL.
enum ReviewRiskURLStatus: Hashable, Codable, Sendable {
    /// 2xx (after redirects).
    case opens
    /// The server answered with this status, e.g. 404.
    case httpError(Int)
    /// No answer: the host doesn't exist, the certificate is wrong, or it
    /// timed out.
    case unreachable(String)

    var opens: Bool { self == .opens }
}
