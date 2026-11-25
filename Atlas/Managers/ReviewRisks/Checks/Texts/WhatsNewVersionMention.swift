//
//  WhatsNewVersionMention.swift
//  Atlas
//

import Foundation

/// Finds a What's New written for another version: "New in Alba 1.2.1"
/// or "Version 1.2.1:" while 1.2.2 is being prepared. Only numbers named
/// as the app's version count ("version", "v", the app's name, "new in",
/// or the text's first word); "iOS 18.2" or "Swift 6.0" don't.
enum WhatsNewVersionMention {
    /// The first version the text names that isn't `version` (nor the
    /// start of it, like "1.2" for "1.2.1").
    static func otherVersion(in text: String, preparing version: String, appName: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        for match in numbers?.matches(in: text, range: range) ?? [] {
            guard let found = Range(match.range, in: text) else { continue }
            let number = String(text[found])
            // "v1.2.1" is a version; "A1.2" isn't.
            if let before = text[..<found.lowerBound].last, before.isLetter, before != "v", before != "V" { continue }
            guard isNamedAsVersion(before: text[..<found.lowerBound], appName: appName), !same(number, version) else { continue }
            return number
        }
        return nil
    }

    /// Whether `number` is `version`, or the start of it, trailing zeros
    /// ignored ("1.2.0" is "1.2").
    static func same(_ number: String, _ version: String) -> Bool {
        let mentioned = parts(number)
        let preparing = parts(version)
        return mentioned == preparing || (mentioned.count < preparing.count && Array(preparing.prefix(mentioned.count)) == mentioned)
    }

    private static func parts(_ version: String) -> [Int] {
        var parts = version.split(separator: ".").compactMap { Int($0) }
        while parts.count > 1, parts.last == 0 { parts.removeLast() }
        return parts
    }

    /// "1.2", "1.2.1", "10.4.0.1"; not inside a longer number or a date.
    private static let numbers = try? NSRegularExpression(pattern: "(?<![\\p{N}.,/-])\\d{1,3}(?:\\.\\d{1,4}){1,3}(?![\\p{N}]|[.,/-]\\d)")

    private static func isNamedAsVersion(before prefix: Substring, appName: String) -> Bool {
        let context = fold(String(prefix.suffix(60)))
        if context.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters).union(.symbols)).isEmpty {
            return true
        }
        if context.range(of: versionWords, options: .regularExpression) != nil { return true }
        return names(of: appName).contains { name in
            context.range(of: "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: name) + "\\s*$", options: .regularExpression) != nil
        }
    }

    /// The words that name a version, right before the number.
    private static let versionWords: String = {
        let words = ["version", "versão", "versión", "versione", "versie", "wersja", "sürüm", "versjon", "バージョン", "版本", "버전"]
            .map(WhatsNewVersionMention.fold)
            .map(NSRegularExpression.escapedPattern(for:))
        let phrases = ["ver\\.?", "v", "new\\s+in", "neu\\s+in", "novidades\\s+(?:da|do|na)", "novedades\\s+de\\s+la", "nouveautes\\s+de\\s+la"]
        return "(?<![\\p{L}])(?:" + (words + phrases).joined(separator: "|") + ")\\s*$"
    }()

    /// The app's name and its parts before ":" or a dash, folded: "Alba:
    /// Daily Motivation" is also "Alba".
    private static func names(of appName: String) -> [String] {
        let folded = fold(appName).trimmingCharacters(in: .whitespaces)
        guard !folded.isEmpty else { return [] }
        let short = folded.components(separatedBy: CharacterSet(charactersIn: ":|–—-·")).first?.trimmingCharacters(in: .whitespaces) ?? ""
        return [folded, short].filter { $0.count >= 2 }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
