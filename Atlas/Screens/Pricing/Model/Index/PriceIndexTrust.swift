//
//  PriceIndexTrust.swift
//  Atlas
//

import Foundation

/// How far one territory's index value can be trusted, for HowSure.
enum PriceIndexTrust: Hashable, Sendable {
    /// A published figure from the source's current edition.
    case exact
    /// Derived from another series (e.g. PPP ÷ exchange rate) or the next
    /// source in the chain, still published data.
    case fallback
    /// Sample or estimated data (a region median, the old prototype values).
    case approximate
    /// Published, but the edition is older than `PriceIndexSnapshot.staleAfterMonths`.
    case stale
    /// No value for the territory.
    case missing

    /// Real published data, recent enough to count toward "Fairly sure".
    var countsAsReal: Bool { self == .exact || self == .fallback }
}
