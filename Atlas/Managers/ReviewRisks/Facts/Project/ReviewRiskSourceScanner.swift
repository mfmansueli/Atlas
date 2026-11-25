//
//  ReviewRiskSourceScanner.swift
//  Atlas
//

import Foundation

/// Reads one Swift file for the App Review checks: the modules it imports
/// and the lines that match `ReviewRiskCodePatterns`, with comments left
/// out so a note about the camera isn't a camera.
enum ReviewRiskSourceScanner {
    /// `import X`, `@testable import X`, `import struct X.Y`: X.
    private static let importExpression = try? NSRegularExpression(
        pattern: #"^\s*(?:@\w+(?:\([^)]*\))?\s+)*import\s+(?:(?:class|struct|enum|protocol|func|var|let|typealias)\s+)?([A-Za-z_][A-Za-z0-9_]*)"#
    )

    /// Adds what `text` (the file at `file`, relative to the project
    /// folder) shows to `facts`.
    static func scan(
        _ text: String,
        file: String,
        into facts: inout ReviewRiskProjectFacts,
        patterns: [ReviewRiskCodePattern] = ReviewRiskCodePatterns.all
    ) {
        let lowercased = text.lowercased()
        let candidates = patterns.filter { $0.mayMatch(text, lowercased: lowercased) }
        let raw = lines(text)
        let code = codeLines(text)
        let ignoresCase = candidates.contains(where: \.caseInsensitive)
        for (index, line) in code.enumerated() where !line.isEmpty {
            if line.contains("import"), let module = importedModule(line) {
                facts.imports.insert(module)
            }
            guard !candidates.isEmpty else { continue }
            let lowerLine = ignoresCase ? line.lowercased() : line
            for pattern in candidates where pattern.mayMatch(line, lowercased: lowerLine) && pattern.matches(line) {
                let excerpt = index < raw.count ? raw[index] : line
                facts.add(ReviewRiskCodeMatch(what: pattern.what, file: file, line: index + 1, excerpt: excerpt), for: pattern.target)
            }
        }
    }

    /// The module an `import` line names, or nil.
    static func importedModule(_ line: String) -> String? {
        guard let importExpression,
              let match = importExpression.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line)
        else { return nil }
        return String(line[range])
    }

    /// The file's lines, without line ends.
    static func lines(_ text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            line.hasSuffix("\r") ? String(line.dropLast()) : String(line)
        }
    }

    /// The file's lines with `//` and `/* */` comments left out (strings
    /// kept, so "Delete Account" still counts), one per line of the file.
    static func codeLines(_ text: String) -> [String] {
        var blockDepth = 0
        return lines(text).map { codeLine($0, blockDepth: &blockDepth) }
    }

    /// One line without its comments; `blockDepth` carries a `/* */` left
    /// open to the next line.
    private static func codeLine(_ line: String, blockDepth: inout Int) -> String {
        var output = ""
        var inString = false
        var index = line.startIndex
        while index < line.endIndex {
            let character = line[index]
            let next = line.index(after: index)
            let following: Character? = next < line.endIndex ? line[next] : nil
            if blockDepth > 0 {
                index = blockCommentStep(character, following, next: next, in: line, depth: &blockDepth)
                continue
            }
            if inString {
                output.append(character)
                if character == "\\", let following {
                    output.append(following)
                    index = line.index(after: next)
                    continue
                }
                if character == "\"" { inString = false }
                index = next
                continue
            }
            if character == "\"" {
                inString = true
            } else if character == "/", following == "/" {
                break
            } else if character == "/", following == "*" {
                blockDepth += 1
                index = line.index(after: next)
                continue
            }
            output.append(character)
            index = next
        }
        return output
    }

    /// Inside a block comment: where to read next, with nested `/*` and
    /// the closing `*/` counted.
    private static func blockCommentStep(
        _ character: Character, _ following: Character?, next: String.Index, in line: String, depth: inout Int
    ) -> String.Index {
        if character == "*", following == "/" {
            depth -= 1
            return line.index(after: next)
        }
        if character == "/", following == "*" {
            depth += 1
            return line.index(after: next)
        }
        return next
    }
}
