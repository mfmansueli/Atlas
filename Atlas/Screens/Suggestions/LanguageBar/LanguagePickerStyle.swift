//
//  LanguagePickerStyle.swift
//  Atlas
//

import Foundation

/// How big the language picker is (README-DS §12).
enum LanguagePickerStyle: Hashable, Sendable {
    /// In the language bar: the flag, the full name and, under it, "5
    /// suggestions here" in purple.
    case full
    /// Where the bar doesn't fit or nothing is counted (Overview's App
    /// Store preview, Retention, the Autopilot studio): one line, the flag,
    /// the full name and the purple count. The same menu.
    case compact
}
