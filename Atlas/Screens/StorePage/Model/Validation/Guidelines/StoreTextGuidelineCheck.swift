//
//  StoreTextGuidelineCheck.swift
//  Atlas
//

import Foundation

/// Finds what App Review rejects in store text and screenshot captions:
/// pricing, other platforms, unverifiable claims, other apps' names,
/// betas, placeholders, "coming soon" and "For Kids"
/// (`StoreTextGuidelineKind`). Assistants' proposals that break one are
/// refused with the reason; the Store Page and Review & Push warn the
/// person, who can still push what they typed.
nonisolated enum StoreTextGuidelineCheck {
    /// The rules `text` breaks in `field`, in `StoreTextGuidelineKind`'s
    /// order; none for URLs.
    static func issues(in text: String, for field: ListingField) -> [StoreTextGuidelineIssue] {
        issues(in: text, kinds: StoreTextGuidelineKind.allCases.filter { $0.applies(to: field) })
    }

    /// The rules an in-app text breaks. An in-app purchase may name a
    /// trial length: 3.1.1 asks a non-subscription app's free trial to be
    /// a non-consumable named "XX-day Trial", as SimProps's "7-day Trial"
    /// is. Subscriptions set trials as introductory offers, which the
    /// App Store shows itself (3.1.2(a)), so theirs are pricing.
    static func issues(in text: String, for field: InAppTextField) -> [StoreTextGuidelineIssue] {
        let allowsTrials = field == .purchaseName || field == .purchaseDescription
        return issues(in: text, kinds: StoreTextGuidelineKind.allCases.filter { $0.applies(to: field) }, allowingTrials: allowsTrials)
    }

    /// The rules a screenshot caption breaks: its headline and subhead.
    static func issues(inCaption headline: String, subhead: String? = nil) -> [StoreTextGuidelineIssue] {
        let text = [headline, subhead ?? ""].filter { !$0.isEmpty }.joined(separator: "\n")
        return issues(in: text, kinds: StoreTextGuidelineKind.allCases.filter(\.checksCaptions))
    }

    /// The rules an In-App Event text, retention message or review reply
    /// breaks, each worded for its place (`StoreTextGuidelinePlace`).
    static func issues(in text: String, for place: StoreTextGuidelinePlace) -> [StoreTextGuidelineIssue] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return place.kinds.compactMap { kind in
            let phrases = phrases(in: text, matching: StoreTextGuidelinePatterns.expressions(for: kind, in: place))
            return phrases.isEmpty ? nil : StoreTextGuidelineIssue(kind: kind, phrases: phrases, place: place)
        }
    }

    static func issues(in text: String, kinds: [StoreTextGuidelineKind], allowingTrials: Bool = false) -> [StoreTextGuidelineIssue] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return kinds.compactMap { kind in
            let expressions = StoreTextGuidelinePatterns.expressions(for: kind, allowingTrials: allowingTrials)
            let phrases = phrases(in: text, matching: expressions)
            return phrases.isEmpty ? nil : StoreTextGuidelineIssue(kind: kind, phrases: phrases)
        }
    }

    /// Every match in the order it appears, overlaps dropped ("R$ 9,90",
    /// not also "$ 9,90"), each phrase once whatever its case.
    static func phrases(in text: String, matching expressions: [NSRegularExpression]) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        let matches = expressions
            .flatMap { $0.matches(in: text, range: range) }
            .compactMap { Range($0.range, in: text) }
            .sorted { $0.lowerBound < $1.lowerBound || ($0.lowerBound == $1.lowerBound && $0.upperBound > $1.upperBound) }
        var phrases: [String] = []
        var seen: Set<String> = []
        var end = text.startIndex
        for match in matches where match.lowerBound >= end {
            end = match.upperBound
            let phrase = text[match].replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !phrase.isEmpty, seen.insert(phrase.lowercased()).inserted { phrases.append(phrase) }
        }
        return phrases
    }
}
