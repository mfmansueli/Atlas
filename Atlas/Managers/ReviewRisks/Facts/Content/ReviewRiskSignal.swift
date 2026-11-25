//
//  ReviewRiskSignal.swift
//  Atlas
//

import Foundation

/// One sign of a topic in an app: the word as written in a store text or
/// the review notes, a package or module in the project, or an age rating
/// answer, with where it is.
struct ReviewRiskSignal: Hashable, Sendable {
    enum Source: String, Hashable, Sendable {
        case storeText
        case reviewNotes
        case project
        case ageRating
        case category
    }

    var topic: ReviewRiskSignalTopic
    /// The word as written, the package or module, or the question's name.
    var term: String
    var source: Source
    var evidence: ReviewRiskEvidence

    /// From the app's words, not the project or the age rating.
    var isText: Bool { source == .storeText || source == .reviewNotes }

    /// The first few signs' evidence, one per place and word.
    static func evidence(_ signals: [ReviewRiskSignal], limit: Int = 3) -> [ReviewRiskEvidence] {
        var seen: Set<String> = []
        return signals.filter { seen.insert($0.evidence.place + "|" + $0.term.lowercased()).inserted }.prefix(limit).map(\.evidence)
    }

    /// "“AI chat” and “OpenAI”": the first two words, at most 24
    /// characters each.
    static func terms(_ signals: [ReviewRiskSignal], limit: Int = 2) -> String {
        var seen: Set<String> = []
        let unique = signals.map { String($0.term.prefix(24)) }.filter { seen.insert($0.lowercased()).inserted }
        return unique.prefix(limit).map { "“\($0)”" }.formatted(.list(type: .and))
    }
}
