//
//  ScreenshotFileTextCheck.swift
//  Atlas
//

import CoreGraphics
import Foundation

/// The text in a screenshot file an assistant sends
/// (`propose_screenshot_file`), read with Vision like the live screenshots
/// App Review checks read (`ScreenshotTextRules`). “Free”, offers, other
/// platforms, Apple's recognitions and placeholder text refuse the file;
/// an amount is often the app's own content, so it only comes back as a
/// note to check.
enum ScreenshotFileTextCheck {
    /// How wide the file is read: enough for Vision to read a caption and
    /// the app's own text.
    static let readingWidth = 1200

    /// Reads the lines in an image; nil when Vision can't.
    typealias Reader = @Sendable (CGImage, String) async -> [String]?

    static let visionReader: Reader = { image, language in
        await ArtworkTextReader.read(image, language: language)?.map(\.text)
    }

    /// Why the file is refused: “The screenshot shows “FREE”. App Review
    /// rejects pricing in store text and screenshots (Guideline 2.3.7).
    /// Send one without it.” Nil when nothing in it refuses it.
    static func refusal(for findings: [ScreenshotTextFinding]) -> String? {
        let refusing = findings.filter(\.kind.refusesFile)
        guard !refusing.isEmpty else { return nil }
        let reasons = refusing.map { finding in
            String(
                localized: "The screenshot shows \(finding.quotedPhrases). \(finding.kind.rule) (\(finding.kind.guidelineLabel)).",
                comment: "kind:error · why an assistant's screenshot file is refused"
            )
        }
        let advice = String(localized: "Send one without it.", comment: "kind:error · how an assistant fixes a refused screenshot file")
        return (reasons + [advice]).joined(separator: " ")
    }

    /// What's worth a look without refusing the file: an amount that may
    /// be the app's own content.
    static func note(for findings: [ScreenshotTextFinding]) -> String? {
        guard let amount = findings.first(where: { $0.kind == .amount }) else { return nil }
        return String(
            localized: "The screenshot shows \(amount.quotedPhrases). If it isn’t the app’s own content, App Review rejects prices in screenshots (Guideline 2.3.7).",
            comment: "kind:error · a note on an assistant's screenshot file"
        )
    }
}
