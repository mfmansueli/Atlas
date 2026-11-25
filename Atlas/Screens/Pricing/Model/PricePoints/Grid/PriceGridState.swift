//
//  PriceGridState.swift
//  Atlas
//

import Foundation

/// Where a product's Apple price points stand. A suggestion is only ever
/// one of Apple's own points (`ProductPriceSheet.hasRealGrid`), so
/// Pricing suggests nothing until every territory's ladder is here: while
/// they're read Prices by Country says "Checking Apple’s prices…" as a
/// plain grey line, and a failed read shows why instead of suggestions.
/// Today's prices show all along: they're Apple's already.
enum PriceGridState: Equatable, Sendable {
    /// Every territory with a price has Apple's own ladder, or the read
    /// finished (a territory Apple sent no points for suggests nothing).
    case ready
    /// Apple's price points are being read, or wait to be.
    case checking
    /// The read failed: why, in `AppleErrorCopy`'s words (what happened ·
    /// what to do, Apple's own text in details).
    case failed(AppleErrorCopy)

    var isReady: Bool { self == .ready }

    var isChecking: Bool { self == .checking }

    /// The failure as one string: what happened, what to do, then Apple's text.
    var failure: String? {
        failureCopy?.text
    }

    /// The failure as the error template shows it.
    var failureCopy: AppleErrorCopy? {
        if case let .failed(copy) = self { return copy }
        return nil
    }

    /// Ready when no territory with a price still has a simulated ladder.
    static func of(_ sheet: ProductPriceSheet) -> PriceGridState {
        sheet.missingLadders(in: sheet.prices.keys).isEmpty ? .ready : .checking
    }

    /// The plain grey line in the banner's place while the points are read.
    static var checkingText: String {
        String(localized: "Checking Apple’s prices…", comment: "kind:hint")
    }

    /// The error's first line, before `AppleErrorCopy` adds what to do.
    static var failureTitle: String {
        String(localized: "Apple’s price points didn’t load.", comment: "kind:error")
    }
}
