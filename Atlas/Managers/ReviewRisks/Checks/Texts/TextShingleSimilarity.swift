//
//  TextShingleSimilarity.swift
//  Atlas
//

import Foundation

/// How much two store texts say word for word: the Jaccard similarity of
/// their three-word runs (shingles), case and accents ignored. Two texts
/// that share a template or a pasted description score high; two that
/// only share a topic score near zero.
enum TextShingleSimilarity {
    static let shingleSize = 3
    /// Fewer shingles than this and a score says little: nil.
    static let minimumShingles = 8

    /// 0...1, or nil when either text is too short to tell.
    static func similarity(_ lhs: String, _ rhs: String) -> Double? {
        let left = shingles(words(in: lhs))
        let right = shingles(words(in: rhs))
        guard left.count >= minimumShingles, right.count >= minimumShingles else { return nil }
        let union = left.union(right).count
        return union == 0 ? nil : Double(left.intersection(right).count) / Double(union)
    }

    /// The longest run of words `lhs` shares with `rhs`, as `lhs` writes
    /// it, for the evidence; nil when they share no shingle.
    static func sharedPassage(_ lhs: String, _ rhs: String) -> String? {
        let words = Self.words(in: lhs)
        let shared = shingles(Self.words(in: rhs))
        guard words.count >= shingleSize else { return nil }
        var best: Range<Int>?
        var start: Int?
        for index in 0...words.count - shingleSize {
            let isShared = shared.contains(words[index..<index + shingleSize].joined(separator: " "))
            if isShared, start == nil { start = index }
            if !isShared || index == words.count - shingleSize, let first = start {
                let last = isShared ? index : index - 1
                let run = first..<last + shingleSize
                if run.count > (best?.count ?? 0) { best = run }
                start = nil
            }
        }
        return best.map { words[$0].joined(separator: " ") }
    }

    static func words(in text: String) -> [String] {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        var words: [String] = []
        folded.enumerateSubstrings(in: folded.startIndex..., options: .byWords) { word, _, _, _ in
            if let word { words.append(word) }
        }
        return words
    }

    static func shingles(_ words: [String]) -> Set<String> {
        guard words.count >= shingleSize else { return [] }
        return Set((0...words.count - shingleSize).map { words[$0..<$0 + shingleSize].joined(separator: " ") })
    }
}
