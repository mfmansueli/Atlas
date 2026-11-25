//
//  WatchProposal.swift
//  Atlas
//

import Foundation

/// One thing a Look for Improvements run sent through Atlas's tools.
struct WatchProposal: Hashable, Codable, Sendable {
    /// e.g. "suggest_fields".
    var tool: String
    /// The activity log's target: "Lumen Journal · de-DE · What’s New".
    var target: String
    var date: Date
}
