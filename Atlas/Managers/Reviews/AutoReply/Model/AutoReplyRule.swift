//
//  AutoReplyRule.swift
//  Atlas
//

import Foundation

/// One app's Reply Automatically settings (board 58), off by default and
/// part of Pro. Only reviews written after it was turned on are answered;
/// nothing older than `maximumAge` goes out by itself.
struct AutoReplyRule: Codable, Hashable, Sendable {
    var isOn = false
    var isPaused = false
    /// When it was last turned on: older reviews are left alone.
    var onSince: Date?
    var mode: AutoReplyMode = .draftAndTell
    /// The ratings whose replies may go out by themselves.
    var ratings: Set<Int> = [4, 5]
    /// The languages ("de", "ja") whose replies may go out by themselves;
    /// empty is every language.
    var languages: Set<String> = []
    /// What always waits for the person.
    var waitTopics: Set<AutoReplyTopic> = Set(AutoReplyTopic.allCases)
    var delay: AutoReplyDelay = .hour
    /// At most this many go out by themselves in a day.
    var dailyCap = 10
    var tone: AutoReplyTone = .warm
    var signature = ""

    /// Nothing older than this is sent automatically.
    static let maximumAge: TimeInterval = 7 * 24 * 60 * 60
    static let dailyCapRange = 1...50

    /// On and not paused.
    var isActive: Bool { isOn && !isPaused }

    /// "4★ and 5★ in every language, after 1 hour": what may go out by
    /// itself, for the strip.
    var summary: String {
        guard mode == .sendAllowed else { return String(localized: "Drafts a reply to each new review and tells you") }
        let stars = ratings.sorted().map { "\($0)★" }.formatted(.list(type: .and))
        let place = languages.isEmpty
            ? String(localized: "every language")
            : languages.sorted().map(ReviewLanguage.name(of:)).formatted(.list(type: .and))
        return String(localized: "\(stars) in \(place) go out after \(delay.title)")
    }
}
