//
//  ReviewRiskCodeMatch.swift
//  Atlas
//

import Foundation

/// One place in the app's code that shows something a check needs: a
/// sign-up call, a camera session, a Google Sign-In import.
struct ReviewRiskCodeMatch: Hashable, Sendable {
    /// What it is, in the person's words: "Google Sign-In", "AVCaptureDevice".
    var what: String
    /// The file, relative to the project folder: "Scanner/CameraView.swift".
    var file: String
    /// 1-based.
    var line: Int
    /// The line as written, trimmed.
    var excerpt: String

    init(what: String, file: String, line: Int, excerpt: String) {
        self.what = what
        self.file = file
        self.line = line
        self.excerpt = excerpt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "Scanner/CameraView.swift:42".
    var place: String { "\(file):\(line)" }
}
