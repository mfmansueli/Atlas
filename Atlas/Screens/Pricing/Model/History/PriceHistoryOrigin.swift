//
//  PriceHistoryOrigin.swift
//  Atlas
//

import Foundation

/// How Atlas learned of a price change. (`ChangeOrigin` names the
/// assistant run behind a proposal, so it doesn't fit here.)
enum PriceHistoryOrigin: String, Hashable, Codable, Sendable {
    /// Pushed from Review & Push.
    case pushed
    /// Found when reading App Store Connect: made there, or on another Mac.
    case read
}
