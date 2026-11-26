//
//  AppInformationReviewEstimate.swift
//  Atlas
//

import Foundation

/// The blue line under App Information's sentence (board 88): how many
/// suggestions Accept All Pages holds, and about how long reviewing them
/// takes, as "19 suggestions · about 10 min".
///
/// The rule: half a minute per suggestion (its value, its reason and what
/// it replaces, then Accept or Dismiss), rounded up to whole minutes, and
/// never under 1 min. 1 → 1 min, 4 → 2 min, 19 → 10 min.
enum AppInformationReviewEstimate {
    static let secondsPerSuggestion = 30

    /// 0 with nothing to review.
    static func minutes(for count: Int) -> Int {
        guard count > 0 else { return 0 }
        return max(1, (count * secondsPerSuggestion + 59) / 60)
    }

    static func text(for count: Int) -> String {
        let minutes = minutes(for: count)
        switch count {
        case ...0:
            return String(localized: "No suggestions waiting", comment: "kind:status · App Information header, nothing to review")
        case 1:
            return String(localized: "1 suggestion · about \(minutes) min", comment: "kind:status · App Information header, one suggestion and the minutes to review it")
        default:
            return String(localized: "\(count) suggestions · about \(minutes) min", comment: "kind:status · App Information header, suggestions and the minutes to review them")
        }
    }

    /// VoiceOver's: "19 suggestions, about 10 minutes to review".
    static func accessibilityText(for count: Int) -> String {
        guard count > 0 else { return text(for: count) }
        return String(
            localized: "\(count) suggestions, about \(minutes(for: count)) minutes to review",
            comment: "kind:accessibility · App Information header, suggestions and the minutes to review them"
        )
    }
}
