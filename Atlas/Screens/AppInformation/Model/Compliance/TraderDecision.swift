//
//  TraderDecision.swift
//  Atlas
//

import Foundation

/// The person's answer to the Digital Services Act question. Only they
/// make it: nothing in Atlas answers it for them.
enum TraderDecision: String, Hashable, Codable, Sendable {
    case trader
    case nonTrader
}
