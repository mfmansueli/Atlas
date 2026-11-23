//
//  AutoReplyCenter.swift
//  Atlas
//

import Foundation
import Observation

/// Reply Automatically (board 58, Pro): each app's rule and the replies to
/// its new reviews. On each check Atlas asks the person's Claude Code to
/// write a reply to every new review (`+Writing`); what comes back through
/// `propose_review_replies` is decided by the rule (`AutoReplyDecision`):
/// scheduled to go out by itself after the wait, or waiting for the person
/// with a notification. Due replies go out through the same write as Send
/// Reply (`+Sending`), at most the rule's daily cap, never older than a
/// week, and not before a reply the person sent by hand reached the App
/// Store. An assistant never turns it on, changes its rule or sends.
@MainActor
@Observable
final class AutoReplyCenter {
    static let shared = AutoReplyCenter(directory: sharedDirectory)

    private static var sharedDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return ReviewsStore.defaultDirectory
    }

    private var archives: [StoreApp.ID: AutoReplyArchive] = [:]
    @ObservationIgnored private let directory: URL?
    @ObservationIgnored var now: () -> Date = { .now }
    /// Free can see the settings, not turn them on: the window sets it.
    @ObservationIgnored var isPro: @MainActor () -> Bool = { true }
    @ObservationIgnored var notifier: AtlasNotifier = .shared
    /// Send Reply on a notification: the main window sends it as the
    /// person's own; false when it isn't there.
    @ObservationIgnored var sendFromNotification: (@MainActor (StoreApp.ID, AppReview.ID) async -> Bool)?
    /// Reviews being sent right now, so a tick doesn't send one twice.
    @ObservationIgnored var sendingIDs: Set<AppReview.ID> = []

    init(directory: URL? = nil) {
        self.directory = directory
    }

    // MARK: - Reading

    func archive(for appID: StoreApp.ID) -> AutoReplyArchive {
        if let archive = archives[appID] { return archive }
        let archive = directory.flatMap { Self.read(at: Self.file(appID, in: $0)) } ?? AutoReplyArchive()
        archives[appID] = archive
        return archive
    }

    func rule(for appID: StoreApp.ID) -> AutoReplyRule {
        archive(for: appID).rule
    }

    /// On, not paused, and the account is on Pro.
    func isActive(for appID: StoreApp.ID) -> Bool {
        rule(for: appID).isActive && isPro()
    }

    func draft(for reviewID: AppReview.ID, appID: StoreApp.ID) -> AutoReplyDraft? {
        archive(for: appID).drafts[reviewID]
    }

    func needsYouCount(for appID: StoreApp.ID) -> Int {
        guard rule(for: appID).isOn, isPro() else { return 0 }
        return archive(for: appID).needsYouCount
    }

    func sentToday(for appID: StoreApp.ID) -> Int {
        archive(for: appID).sentCount(on: now())
    }

    // MARK: - The rule

    /// Turn On or Save: turning it on answers reviews from now on.
    func setRule(_ rule: AutoReplyRule, for appID: StoreApp.ID) {
        update(appID) { archive in
            var rule = rule
            rule.dailyCap = min(max(rule.dailyCap, AutoReplyRule.dailyCapRange.lowerBound), AutoReplyRule.dailyCapRange.upperBound)
            if rule.isOn, !archive.rule.isOn || rule.onSince == nil { rule.onSince = now() }
            if !rule.isOn { rule.isPaused = false }
            archive.rule = rule
            // Turned off: nothing waits to go out any more.
            if !rule.isOn {
                for (id, draft) in archive.drafts where draft.state.isScheduled {
                    archive.drafts[id]?.state = .held
                }
            }
        }
    }

    /// Pause from the strip, the Autopilot menu or the menu bar: new
    /// reviews are drafted and wait; Resume lets them go again.
    func setPaused(_ paused: Bool, for appID: StoreApp.ID) {
        update(appID) { archive in
            guard archive.rule.isOn else { return }
            archive.rule.isPaused = paused
        }
    }

    /// The menu bar's Pause Auto-Reply: every app that has it on.
    func setPaused(_ paused: Bool, forAll appIDs: [StoreApp.ID]) {
        for appID in appIDs where rule(for: appID).isOn {
            setPaused(paused, for: appID)
        }
    }

    /// nil when none of the apps has it on; else whether all those that do
    /// are paused.
    func pausedState(for appIDs: [StoreApp.ID]) -> Bool? {
        let turnedOn = appIDs.map(rule(for:)).filter(\.isOn)
        return turnedOn.isEmpty ? nil : turnedOn.allSatisfy(\.isPaused)
    }

    // MARK: - Replies that arrive

    /// Replies an assistant sent (`propose_review_replies`), with what it
    /// read in each review. Those for reviews written since Reply
    /// Automatically was turned on are decided by the rule; the person is
    /// told about each that waits for them.
    func received(
        _ suggestions: [ReviewReplySuggestion], flags: [AppReview.ID: (topics: Set<AutoReplyTopic>, isUnsure: Bool)],
        reviews: ReviewsArchive, app: StoreApp
    ) {
        let rule = rule(for: app.id)
        guard rule.isOn, isPro(), let since = rule.onSince else { return }
        let date = now()
        var told: [(AppReview, AutoReplyDraftState, String)] = []
        update(app.id) { archive in
            for suggestion in suggestions {
                guard let review = reviews.review(id: suggestion.reviewID), !review.hasReply, review.date >= since else { continue }
                if case .sent = archive.drafts[review.id]?.state { continue }
                let flag = flags[review.id] ?? ([], false)
                var state = AutoReplyDecision.state(
                    for: review, text: suggestion.text, topics: flag.topics, isUnsure: flag.isUnsure, rule: rule, now: date
                )
                // Paused: drafted, and it waits.
                if rule.isPaused, state.isScheduled { state = .needsYou(reason: String(localized: "auto-reply is paused")) }
                archive.drafts[review.id] = AutoReplyDraft(
                    reviewID: review.id, state: state, topics: flag.topics, isUnsure: flag.isUnsure, createdAt: date
                )
                archive.requested[review.id] = nil
                if !state.isScheduled { told.append((review, state, suggestion.text)) }
            }
            archive.writeProblem = nil
        }
        for (review, state, text) in told {
            tell(review, state: state, reply: text, app: app)
        }
    }

    /// The person sent, edited or dismissed the reply themselves: it's
    /// theirs now.
    func personReplied(to reviewID: AppReview.ID, appID: StoreApp.ID) {
        update(appID) { archive in
            guard let draft = archive.drafts[reviewID], !Self.isSent(draft) else { return }
            archive.drafts[reviewID] = nil
        }
    }

    /// Don't Send: it stays under the review, with Send.
    func hold(_ reviewID: AppReview.ID, appID: StoreApp.ID) {
        update(appID) { $0.drafts[reviewID]?.state = .held }
    }

    // MARK: - Telling

    /// "A 1★ review needs your reply": the review and why (Open Reviews),
    /// or that a reply is ready, with its text (Send Reply, Open Reviews).
    private func tell(_ review: AppReview, state: AutoReplyDraftState, reply: String, app: StoreApp) {
        let who = [review.nickname, review.territoryName].filter { !$0.isEmpty }.joined(separator: ", ")
        let quote = review.title.isEmpty ? review.body : review.title
        let userInfo = [AtlasNotificationCategory.appIDKey: app.id, AtlasNotificationCategory.reviewIDKey: review.id]
        switch state {
        case let .needsYou(reason):
            notifier.post(
                .needsYou,
                title: String(localized: "A \(review.rating)★ review needs your reply"),
                body: String(localized: "\(who): “\(quote)”. A draft reply waits for you: \(reason)."),
                identifier: "autoreply.\(app.id).\(review.id)", category: .autoReplyNeedsYou, userInfo: userInfo
            )
        case .drafted:
            notifier.post(
                .needsYou,
                title: String(localized: "A reply is ready for a \(review.rating)★ review"),
                body: String(localized: "\(who): “\(quote)”\nReply: “\(reply)”"),
                identifier: "autoreply.\(app.id).\(review.id)", category: .autoReplyReady, userInfo: userInfo
            )
        case .scheduled, .sent, .held:
            break
        }
    }

    static func isSent(_ draft: AutoReplyDraft) -> Bool {
        if case .sent = draft.state { return true }
        return false
    }

    // MARK: - Files

    func update(_ appID: StoreApp.ID, _ change: (inout AutoReplyArchive) -> Void) {
        var archive = archive(for: appID)
        change(&archive)
        guard archive != archives[appID] else { return }
        archives[appID] = archive
        guard let directory else { return }
        Self.write(archive, to: Self.file(appID, in: directory))
    }

    #if DEBUG
    /// DEBUG scenes and tests: an app's whole state at once.
    func load(_ archive: AutoReplyArchive, for appID: StoreApp.ID) {
        archives[appID] = archive
    }
    #endif

    private static func file(_ appID: StoreApp.ID, in directory: URL) -> URL {
        directory.appending(path: "auto-reply-\(appID).json")
    }

    private static func read(at url: URL) -> AutoReplyArchive? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AutoReplyArchive.self, from: data)
    }

    private static func write(_ archive: AutoReplyArchive, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? encoder.encode(archive).write(to: url, options: .atomic)
    }
}
