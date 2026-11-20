//
//  TextWordDiff.swift
//  Atlas
//

import Foundation

/// The words that change between a text and a suggested revision of it,
/// for the suggestion's Now and Suggested rows (the removed words struck
/// through, the added ones marked) and for an MCP result (`marked`: "…by
/// [-Sunday-]{+December 2+}."). Texts split into words and punctuation,
/// each with the spaces after it; Chinese and Japanese characters count
/// one by one, since they have no spaces between words. Putting the same and removed parts
/// together gives the old text back, the same and added parts the new one.
struct TextWordDiff: Hashable, Sendable {
    enum Segment: Hashable, Sendable {
        case same(String)
        case removed(String)
        case added(String)
    }

    let segments: [Segment]

    init(from old: String, to new: String) {
        let before = Self.tokens(old)
        let after = Self.tokens(new)
        var removed: Set<Int> = []
        var inserted: Set<Int> = []
        for change in after.difference(from: before) {
            switch change {
            case let .remove(offset, _, _): removed.insert(offset)
            case let .insert(offset, _, _): inserted.insert(offset)
            }
        }
        var segments: [Segment] = []
        var oldIndex = 0
        var newIndex = 0
        while oldIndex < before.count || newIndex < after.count {
            if oldIndex < before.count, removed.contains(oldIndex) {
                segments.append(.removed(before[oldIndex]))
                oldIndex += 1
            } else if newIndex < after.count, inserted.contains(newIndex) {
                segments.append(.added(after[newIndex]))
                newIndex += 1
            } else if newIndex < after.count {
                segments.append(.same(after[newIndex]))
                oldIndex += 1
                newIndex += 1
            } else {
                break
            }
        }
        self.segments = Self.merged(segments)
    }

    /// Whether anything changes.
    var hasChanges: Bool {
        segments.contains { if case .same = $0 { false } else { true } }
    }

    /// "…milestone by [-Sunday-]{+December 2+}.": removed words in [- -],
    /// added ones in {+ +}, as `git diff --word-diff` writes them.
    var marked: String {
        segments.map { segment in
            switch segment {
            case let .same(text): text
            case let .removed(text): "[-\(text)-]"
            case let .added(text): "{+\(text)+}"
            }
        }
        .joined()
    }

    /// The words taken out, and the ones put in, each run once.
    var removedWords: [String] {
        segments.compactMap { if case let .removed(text) = $0 { text } else { nil } }
    }

    var addedWords: [String] {
        segments.compactMap { if case let .added(text) = $0 { text } else { nil } }
    }

    // MARK: - Tokens

    /// Words and single punctuation marks, each with the spaces after it
    /// (so a space never matches on its own); ideographs and kana one by
    /// one.
    static func tokens(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var currentKind: Kind?
        var endsInSpace = false
        for character in text {
            let kind = Kind(character)
            if kind == .space, !current.isEmpty {
                current.append(character)
                endsInSpace = true
                continue
            }
            if kind == .word, currentKind == .word, !endsInSpace {
                current.append(character)
                continue
            }
            if !current.isEmpty { tokens.append(current) }
            current = String(character)
            currentKind = kind
            endsInSpace = kind == .space
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private enum Kind: Hashable {
        case word
        case space
        case ideograph
        case mark

        init(_ character: Character) {
            if character.isWhitespace {
                self = .space
            } else if character.unicodeScalars.contains(where: Self.isIdeographic) {
                self = .ideograph
            } else if character.isLetter || character.isNumber || character == "’" || character == "'" {
                self = .word
            } else {
                self = .mark
            }
        }

        private static func isIdeographic(_ scalar: Unicode.Scalar) -> Bool {
            switch scalar.value {
            case 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2FA1F: true
            default: false
            }
        }
    }

    /// Neighbouring segments of the same kind as one.
    private static func merged(_ segments: [Segment]) -> [Segment] {
        var result: [Segment] = []
        for segment in segments {
            switch (result.last, segment) {
            case let (.same(last)?, .same(text)): result[result.count - 1] = .same(last + text)
            case let (.removed(last)?, .removed(text)): result[result.count - 1] = .removed(last + text)
            case let (.added(last)?, .added(text)): result[result.count - 1] = .added(last + text)
            default: result.append(segment)
            }
        }
        return result
    }
}
