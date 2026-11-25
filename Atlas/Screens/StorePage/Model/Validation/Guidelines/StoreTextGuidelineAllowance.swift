//
//  StoreTextGuidelineAllowance.swift
//  Atlas
//

import Foundation

/// What one app may say that `StoreTextGuidelineCheck` would otherwise
/// refuse, so an assistant's proposal isn't refused for words the app is
/// allowed or App Review already approved:
/// - "For Kids" and "For Children" in an app with a Kids age band (it's in
///   the Kids Category, Guideline 2.3.8).
/// - A phrase already in the app's approved name ("Best", "Google"), in the
///   name and subtitle: refusing it would make every name proposal fail.
///
/// The MCP tools that write store text bind it to `current` around their
/// checks (`$current.withValue(_:)`); everywhere else nothing is allowed.
nonisolated struct StoreTextGuidelineAllowance: Hashable, Sendable {
    /// The app has a Kids age band in App Store Connect.
    var isKidsCategory: Bool
    /// The app's approved names, in any language.
    var approvedNames: [String]

    init(isKidsCategory: Bool = false, approvedNames: [String] = []) {
        self.isKidsCategory = isKidsCategory
        self.approvedNames = approvedNames.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// The allowance the checks apply right now; nothing outside a tool
    /// that binds one.
    @TaskLocal static var current: StoreTextGuidelineAllowance = .init()

    /// Allows nothing: the checks' issues stay as they are.
    var allowsNothing: Bool { !isKidsCategory && approvedNames.isEmpty }

    /// `issues` without what this app may say. Approved names count only for
    /// the name and subtitle (`field`); nil is any other place.
    func allowed(_ issues: [StoreTextGuidelineIssue], in field: ListingField?) -> [StoreTextGuidelineIssue] {
        guard !allowsNothing else { return issues }
        let names = field == .name || field == .subtitle ? approvedNames.map(Self.folded) : []
        return issues.compactMap { issue in
            if issue.kind == .kidsTerms, isKidsCategory { return nil }
            guard !names.isEmpty else { return issue }
            var kept = issue
            kept.phrases.removeAll { phrase in names.contains { Self.name($0, contains: Self.folded(phrase)) } }
            return kept.phrases.isEmpty ? nil : kept
        }
    }

    /// Case, accents and width ignored.
    static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// Whole words for Latin phrases ("best" isn't in "Bestie"); anywhere
    /// for scripts without spaces.
    private static func name(_ name: String, contains phrase: String) -> Bool {
        guard !phrase.isEmpty else { return false }
        guard phrase.unicodeScalars.contains(where: { $0.isASCII && CharacterSet.letters.contains($0) }) else {
            return name.contains(phrase)
        }
        let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: phrase) + "(?![\\p{L}\\p{N}])"
        return name.range(of: pattern, options: .regularExpression) != nil
    }
}
