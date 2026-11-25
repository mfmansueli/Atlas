//
//  ReviewRiskCodePattern.swift
//  Atlas
//

import Foundation

/// One thing to look for in a Swift line: a literal `needle` that must be
/// in the file (a cheap test before the regular expression runs) and the
/// expression that confirms it on a line.
struct ReviewRiskCodePattern: Sendable {
    var target: ReviewRiskCodeTarget
    /// What it is, for evidence: "Google Sign-In", "CLLocationManager".
    var what: String
    /// A literal the line must contain; matched case-sensitively.
    var needle: String
    var regex: NSRegularExpression
    /// The needle and the expression ignore case (texts like "Delete Account").
    var caseInsensitive: Bool

    init?(_ target: ReviewRiskCodeTarget, what: String, needle: String, pattern: String, caseInsensitive: Bool = false) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: caseInsensitive ? [.caseInsensitive] : []) else { return nil }
        self.target = target
        self.what = what
        self.needle = needle
        self.regex = regex
        self.caseInsensitive = caseInsensitive
    }

    /// Whether the file can show it: its needle is somewhere in `text`
    /// (`lowercased` is the same text lowercased, for needles that ignore case).
    func mayMatch(_ text: String, lowercased: String) -> Bool {
        caseInsensitive ? lowercased.contains(needle.lowercased()) : text.contains(needle)
    }

    /// Whether `line` shows it.
    func matches(_ line: String) -> Bool {
        let range = NSRange(line.startIndex..., in: line)
        return regex.firstMatch(in: line, range: range) != nil
    }
}
