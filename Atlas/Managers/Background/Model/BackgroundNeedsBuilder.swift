//
//  BackgroundNeedsBuilder.swift
//  Atlas
//

import Foundation

/// Words the menu bar's "Needs you" lines from each app's facts, in the
/// design's order: what Autopilot waits on, event artwork concepts to
/// choose from, an approved version to release, reviews with suggested
/// replies, new Analytics findings, then suggestions to accept. With more than one app in the library each
/// detail starts with the app's name, so "6 reviews need a reply" says
/// whose.
enum BackgroundNeedsBuilder {
    static func needs(for apps: [BackgroundAppFacts], namesApps: Bool) -> [BackgroundNeed] {
        var autopilot: [BackgroundNeed] = []
        var artwork: [BackgroundNeed] = []
        var approved: [BackgroundNeed] = []
        var reviews: [BackgroundNeed] = []
        var findings: [BackgroundNeed] = []
        var suggestions: [BackgroundNeed] = []
        for facts in apps {
            let prefix = namesApps ? facts.appName + " · " : ""
            if let turn = facts.autopilotTurn {
                autopilot.append(BackgroundNeed(
                    id: "autopilot-\(facts.appID)",
                    title: title(for: turn, appName: facts.appName),
                    detail: String(localized: "Autopilot waits here"),
                    destination: .section(.screenshots, appID: facts.appID)
                ))
            }
            for ready in facts.readyArtwork {
                artwork.append(BackgroundNeed(
                    id: "event-artwork-\(facts.appID)-\(ready.eventID)",
                    title: ready.count == 1
                        ? String(localized: "A concept is ready for “\(ready.eventName)”")
                        : String(localized: "\(ready.count) concepts are ready for “\(ready.eventName)”"),
                    detail: prefix + String(localized: "Choose one to finish the event’s images"),
                    destination: .eventArtwork(appID: facts.appID, eventID: ready.eventID)
                ))
            }
            if let version = facts.approvedVersion {
                approved.append(BackgroundNeed(
                    id: "approved-\(facts.appID)",
                    title: String(localized: "\(facts.appName) \(version) was approved"),
                    detail: String(localized: "You chose to release it yourself · Release…"),
                    destination: .version(appID: facts.appID)
                ))
            }
            if facts.reviewReplies > 0 {
                reviews.append(BackgroundNeed(
                    id: "reviews-\(facts.appID)",
                    title: facts.reviewReplies == 1
                        ? String(localized: "1 review needs a reply")
                        : String(localized: "\(facts.reviewReplies) reviews need a reply"),
                    detail: prefix + String(localized: "Replies are suggested in each language"),
                    destination: .section(.reviews, appID: facts.appID)
                ))
            }
            if facts.newFindings > 0 {
                findings.append(BackgroundNeed(
                    id: "findings-\(facts.appID)",
                    title: facts.newFindings == 1
                        ? String(localized: "1 new finding in Analytics")
                        : String(localized: "\(facts.newFindings) new findings in Analytics"),
                    detail: prefix + (facts.firstFindingTitle ?? String(localized: "What to try next, from Apple’s reports")),
                    destination: .section(.analytics, appID: facts.appID),
                    isSuggestion: true
                ))
            }
            if facts.openSuggestions > 0 {
                suggestions.append(BackgroundNeed(
                    id: "suggestions-\(facts.appID)",
                    title: facts.openSuggestions == 1
                        ? String(localized: "1 suggestion to review")
                        : String(localized: "\(facts.openSuggestions) suggestions to review"),
                    detail: prefix + String(localized: "Nothing changes until you accept it"),
                    destination: .section(.overview, appID: facts.appID),
                    isSuggestion: true
                ))
            }
        }
        return autopilot + artwork + approved + reviews + findings + suggestions
    }

    /// "Choose the look for Lumen Journal’s screenshots".
    static func title(for turn: AutopilotTurn, appName: String) -> String {
        switch turn {
        case .pick: String(localized: "Pick the captures for \(appName)’s screenshots")
        case .choose: String(localized: "Choose the look for \(appName)’s screenshots")
        case .review: String(localized: "Review \(appName)’s screenshots, then push")
        }
    }

    /// The turn a run's stage waits on: the three checkpoints, and Review
    /// & Push once everything is made.
    static func turn(for stage: AutopilotStage) -> AutopilotTurn? {
        switch stage {
        case .pick: .pick
        case .choose: .choose
        case .watchPreview, .ready: .review
        case .plan, .waiting, .capture, .design, .localize: nil
        }
    }
}
