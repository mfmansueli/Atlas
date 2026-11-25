//
//  StoreTextAppleTrademarks.swift
//  Atlas
//

import Foundation

/// Apple's trademarks in store text (Guideline 5.2.5 and Apple's trademark
/// guidelines): "iPhone", "Apple Watch", "Siri"… An app may say what it
/// runs on in a referential phrase ("for iPhone", "for iPad and Mac"), but
/// not use them as its own name. "Mac" and "Apple" are often something
/// else ("Mac and Cheese", "Apple Pie Recipes"), so only their exact
/// capitalization counts, and as `isAmbiguous`.
nonisolated enum StoreTextAppleTrademarks {
    /// One trademark as written, and how it's used.
    struct Use: Hashable, Sendable {
        var term: String
        /// After "for" (or a list that started with it): what the app runs on.
        var isReferential: Bool
        /// "Mac" or "Apple": could be the word, not the trademark.
        var isAmbiguous: Bool
    }

    /// Each trademark in `text`, in order, once whatever its case.
    static func uses(in text: String) -> [Use] {
        let range = NSRange(text.startIndex..., in: text)
        var found: [(range: Range<String.Index>, ambiguous: Bool)] = []
        for (expression, isAmbiguous) in [(Self.clear, false), (Self.ambiguous, true)] {
            for match in expression?.matches(in: text, range: range) ?? [] {
                if let matched = Range(match.range, in: text) { found.append((matched, isAmbiguous)) }
            }
        }
        found.sort { $0.range.lowerBound < $1.range.lowerBound || ($0.range.lowerBound == $1.range.lowerBound && $0.range.upperBound > $1.range.upperBound) }
        var uses: [Use] = []
        var seen: Set<String> = []
        var end = text.startIndex
        var previous: (end: String.Index, referential: Bool)?
        for match in found where match.range.lowerBound >= end {
            end = match.range.upperBound
            let before = String(text[..<match.range.lowerBound].suffix(24))
            var referential = before.range(of: referentialEnd, options: [.regularExpression, .caseInsensitive]) != nil
            // "for iPhone and iPad": the list keeps the first one's "for".
            if !referential, let previous, previous.referential,
               text[previous.end..<match.range.lowerBound].range(of: listGlue, options: [.regularExpression, .caseInsensitive]) != nil
            {
                referential = true
            }
            previous = (match.range.upperBound, referential)
            let term = String(text[match.range])
            if seen.insert(term.lowercased()).inserted {
                uses.append(Use(term: term, isReferential: referential, isAmbiguous: match.ambiguous))
            }
        }
        return uses
    }

    /// The trademarks among comma-separated keywords, as written ("mac"
    /// in lower case is left out: it's often the word).
    static func keywordTerms(in keywords: String) -> [String] {
        uses(in: keywords).map(\.term)
    }

    // MARK: - Patterns

    /// Longest first, so "Apple Watch" wins over a lone "Apple".
    private static let clearTerms = [
        "Apple Vision Pro", "Apple Watch", "Apple TV", "Apple Pay", "Apple Music", "Apple Pencil", "Apple Arcade", "Vision Pro",
        "App Store", "iPhone", "iPad", "iPod", "AirPods", "AirTag", "iMessage", "FaceTime", "Siri", "macOS", "iOS", "iPadOS",
        "watchOS", "visionOS", "tvOS", "HomePod", "iCloud", "CarPlay", "MacBook", "iMac", "Mac mini", "Mac Pro", "Mac Studio",
    ]

    private static let clear = try? NSRegularExpression(
        pattern: "(?<![\\p{L}\\p{N}])(?:" + clearTerms.map { NSRegularExpression.escapedPattern(for: $0).replacingOccurrences(of: " ", with: "\\s+") }
            .joined(separator: "|") + ")(?![\\p{L}\\p{N}])",
        options: [.caseInsensitive]
    )

    /// Case-sensitive: "Mac" and "Apple", not "mac" or "APPLE".
    private static let ambiguous = try? NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}])(?:Mac|Apple)(?![\\p{L}\\p{N}])")

    /// The words that make it referential, right before the trademark:
    /// "for", "for your", "para", "pour", "für", "per", "voor", "för"…
    private static let referentialEnd =
        "(?<![\\p{L}])(?:for|para|pour|für|per|voor|för|for\\s+your|for\\s+the|para\\s+o|para\\s+tu|para\\s+seu"
            + "|pour\\s+votre|für\\s+dein|dla|na|con|with|avec|mit|com|on|sur|auf)\\s+$"

    /// What joins a list of trademarks: "iPhone, iPad and Mac".
    private static let listGlue = "^\\s*(?:,|&|/|and|or|e|y|et|und|o|ou|en|och|i)?\\s*,?\\s*$"
}
