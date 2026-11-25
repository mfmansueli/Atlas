//
//  ReviewRiskURLProbing.swift
//  Atlas
//

import Foundation

/// Checks whether a URL opens: a HEAD request (GET when the server
/// refuses HEAD), following redirects, with a short timeout.
protocol ReviewRiskURLProbing: Sendable {
    func probe(_ url: URL) async -> ReviewRiskURLStatus
}
