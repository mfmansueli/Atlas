//
//  PrivacyPageStatus.swift
//  Atlas
//

import Foundation

/// The pill beside App Privacy's tabs: what still waits in the worksheet
/// ("1 question · 3 to review"), then whether it's ready for App Store
/// Connect, or when it was published there.
struct PrivacyPageStatus: Hashable, Sendable {
    /// Picks the pill's colors: green once published, accent when ready,
    /// amber while something waits or App Store Connect may not match.
    enum Tone: Hashable, Sendable {
        case published
        case ready
        case waiting
        case outOfDate
        case neutral
    }

    let text: String
    let tone: Tone

    init(worksheet: PrivacyWorksheet) {
        self.init(status: worksheet.status, openQuestions: worksheet.openQuestions.count, unreviewed: worksheet.unreviewedCount)
    }

    init(status: PrivacyWorksheetStatus, openQuestions: Int, unreviewed: Int) {
        switch status {
        case let .published(date):
            let day = date.formatted(.dateTime.month(.abbreviated).day())
            text = String(localized: "Published in App Store Connect · \(day)", comment: "kind:pill")
            tone = .published
        case .outOfDate:
            text = status.title
            tone = .outOfDate
        case .notStarted:
            text = status.title
            tone = .neutral
        case .inProgress, .done:
            if let waiting = Self.waitingText(openQuestions: openQuestions, unreviewed: unreviewed) {
                text = waiting
                tone = .waiting
            } else if status == .done {
                text = String(localized: "Ready to fill in App Store Connect", comment: "kind:pill")
                tone = .ready
            } else {
                text = status.title
                tone = .neutral
            }
        }
    }

    /// "1 question · 3 to review", "2 questions" or "3 to review"; nil when
    /// nothing waits.
    static func waitingText(openQuestions: Int, unreviewed: Int) -> String? {
        var parts: [String] = []
        if openQuestions == 1 {
            parts.append(String(localized: "1 question", comment: "kind:pill"))
        } else if openQuestions > 1 {
            parts.append(String(localized: "\(openQuestions) questions", comment: "kind:pill"))
        }
        if unreviewed > 0 {
            parts.append(String(localized: "\(unreviewed) to review", comment: "kind:pill"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The Worksheet tab's count: suggestions to review and open questions.
    static func worksheetCount(_ worksheet: PrivacyWorksheet) -> Int {
        worksheet.unreviewedCount + worksheet.openQuestions.count
    }
}
