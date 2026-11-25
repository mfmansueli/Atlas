//
//  ReviewRiskPurposeStringReader.swift
//  Atlas
//

import Foundation

/// Reads permission texts (purpose strings) and the languages they're in:
/// Info.plist files, `INFOPLIST_KEY_…` build settings in project.pbxproj,
/// InfoPlist.xcstrings and *.lproj/InfoPlist.strings, and the project's
/// regions.
enum ReviewRiskPurposeStringReader {
    /// `INFOPLIST_KEY_NSCameraUsageDescription = "Scans receipts";` or an
    /// unquoted value.
    private static let buildSetting = try? NSRegularExpression(
        pattern: #"INFOPLIST_KEY_((?:NS\w+UsageDescription)|NFCReaderUsageDescription)\s*=\s*(?:"((?:[^"\\]|\\.)*)"|([^;"]*));"#
    )
    private static let knownRegions = try? NSRegularExpression(pattern: #"knownRegions\s*=\s*\(([^)]*)\)"#)
    private static let developmentRegion = try? NSRegularExpression(pattern: #"developmentRegion\s*=\s*"?([A-Za-z_-]+)"?\s*;"#)

    /// The purpose strings in an Info.plist, placed at their line in `file`.
    static func infoPlist(_ data: Data, file: String) -> [ReviewRiskPurposeString] {
        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return [] }
        let lines = String(data: data, encoding: .utf8).map(ReviewRiskSourceScanner.lines) ?? []
        return plist.keys.sorted().filter(ReviewRiskPermission.isPurposeKey).map { key in
            let value = plist[key] as? String ?? ""
            let line = lines.firstIndex { $0.contains("<key>\(key)</key>") }
            return ReviewRiskPurposeString(key: key, value: value, place: line.map { "\(file):\($0 + 1)" } ?? file)
        }
    }

    /// The `INFOPLIST_KEY_…UsageDescription` build settings in a
    /// project.pbxproj, the first of each key (every configuration repeats it).
    static func buildSettings(_ text: String, file: String) -> [ReviewRiskPurposeString] {
        guard let buildSetting else { return [] }
        var found: [String: ReviewRiskPurposeString] = [:]
        var order: [String] = []
        for (index, line) in ReviewRiskSourceScanner.lines(text).enumerated() where line.contains("INFOPLIST_KEY_") {
            let range = NSRange(line.startIndex..., in: line)
            for match in buildSetting.matches(in: line, range: range) {
                guard let keyRange = Range(match.range(at: 1), in: line) else { continue }
                let key = String(line[keyRange])
                let value: String = if let quoted = Range(match.range(at: 2), in: line) {
                    unescape(String(line[quoted]))
                } else if let bare = Range(match.range(at: 3), in: line) {
                    String(line[bare]).trimmingCharacters(in: .whitespaces)
                } else {
                    ""
                }
                let purpose = ReviewRiskPurposeString(key: key, value: value, place: "\(file):\(index + 1)")
                if let existing = found[key] {
                    if !existing.isWritten, purpose.isWritten { found[key] = purpose }
                } else {
                    found[key] = purpose
                    order.append(key)
                }
            }
        }
        return order.compactMap { found[$0] }
    }

    /// A string catalog: each key's translated languages, every language it
    /// has, and its source language.
    static func stringCatalog(_ data: Data) -> (keys: [String: Set<String>], languages: Set<String>, source: String?) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return ([:], [], nil) }
        let source = json["sourceLanguage"] as? String
        var keys: [String: Set<String>] = [:]
        var languages: Set<String> = source.map { [ReviewRiskLanguageCode.base($0)] } ?? []
        for (key, entry) in json["strings"] as? [String: Any] ?? [:] {
            let localizations = (entry as? [String: Any])?["localizations"] as? [String: Any] ?? [:]
            let translated = localizations.compactMap { language, value -> String? in
                guard let value = value as? [String: Any] else { return nil }
                if let unit = value["stringUnit"] as? [String: Any], let text = unit["value"] as? String, !text.isEmpty { return language }
                return value["variations"] != nil ? language : nil
            }
            let bases = Set(translated.map(ReviewRiskLanguageCode.base))
            keys[key] = bases
            languages.formUnion(bases)
        }
        return (keys, languages, source)
    }

    /// A .strings file's keys that have a value.
    static func stringsFile(_ data: Data) -> Set<String> {
        guard let table = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return [] }
        return Set(table.compactMap { key, value -> String? in
            guard let text = value as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return key
        })
    }

    /// project.pbxproj's `developmentRegion` and `knownRegions` (without Base).
    static func regions(_ text: String) -> (development: String?, known: Set<String>) {
        let range = NSRange(text.startIndex..., in: text)
        var development: String?
        if let match = developmentRegion?.firstMatch(in: text, range: range), let found = Range(match.range(at: 1), in: text) {
            development = String(text[found])
        }
        var known: Set<String> = []
        for match in knownRegions?.matches(in: text, range: range) ?? [] {
            guard let list = Range(match.range(at: 1), in: text) else { continue }
            for item in text[list].split(separator: ",") {
                let region = item.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"")))
                guard !region.isEmpty, region.lowercased() != "base" else { continue }
                known.insert(ReviewRiskLanguageCode.base(region))
            }
        }
        return (development, known)
    }

    /// A quoted pbxproj value: `\"`, `\\` and `\n` read back.
    private static func unescape(_ text: String) -> String {
        guard text.contains("\\") else { return text }
        var result = ""
        var escaping = false
        for character in text {
            if escaping {
                switch character {
                case "n": result.append("\n")
                case "t": result.append("\t")
                default: result.append(character)
                }
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        return result
    }
}
