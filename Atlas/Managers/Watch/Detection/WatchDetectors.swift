//
//  WatchDetectors.swift
//  Atlas
//

import Foundation

/// Look for Improvements' own checks (no AI, free for everyone): pure
/// functions over what the hourly check already read (`WatchInputs`),
/// each giving the findings of one kind. Their summaries are for the
/// assistant's prompt, in English.
enum WatchDetectors {
    /// An event's card showing this soon counts.
    static let eventWindow: TimeInterval = 7 * 24 * 3600
    /// Reviews since a release before they say anything.
    static let reviewsNeeded = 5
    /// Reviews before it, to compare the average with.
    static let reviewsBeforeNeeded = 5
    /// How far back "before" reaches.
    static let reviewsBeforeWindow: TimeInterval = 90 * 24 * 3600
    /// Stars the average has to fall by.
    static let ratingDrop = 0.5
    /// 1–2 star reviews since the release that count as a theme to group…
    static let lowReviewsNeeded = 3
    /// …when they're at least this share of them.
    static let lowShare = 0.3

    /// Every finding in `inputs`, in `WatchSignalKind`'s order.
    static func signals(in inputs: WatchInputs) -> [WatchSignal] {
        [blocked(inputs), rejected(inputs), reviewRisks(inputs)].compactMap(\.self) + events(inputs)
            + [whatsNew(inputs), crashes(inputs), reviews(inputs)].compactMap(\.self)
    }

    // MARK: - Local only

    /// The version being prepared still lacks answers only the person gives.
    static func blocked(_ inputs: WatchInputs) -> WatchSignal? {
        guard let version = inputs.version, version.phase == .prepare, !inputs.blockers.isEmpty else { return nil }
        let blockers = inputs.blockers.map(\.summary).joined(separator: ", ")
        return WatchSignal(
            kind: .submissionBlocked, appID: inputs.appID, subject: version.id, value: Double(inputs.blockers.count),
            numbers: ["blockers": Double(inputs.blockers.count)],
            summary: "Version \(version.versionString) can't be submitted yet: it still needs \(blockers)."
        )
    }

    /// App Review sent the version back.
    static func rejected(_ inputs: WatchInputs) -> WatchSignal? {
        guard let version = inputs.version, version.phase == .rejected else { return nil }
        return WatchSignal(
            kind: .versionRejected, appID: inputs.appID, subject: version.id, value: 1,
            summary: "App Review rejected version \(version.versionString)."
        )
    }

    // MARK: - Sent to the assistant

    /// Most App Review risks named in one finding; the assistant reads the
    /// rest with get_review_risks.
    static let reviewRisksNamed = 8

    /// App Review risks an assistant can act on: those whose fix names a
    /// tool, and the project checks nobody answered when the folder is known.
    static func reviewRisks(_ inputs: WatchInputs) -> WatchSignal? {
        let fixable = inputs.reviewRisks.filter { $0.fix.tool != nil }
        let project = inputs.hasProjectFolder ? inputs.unansweredProjectChecks : []
        guard !fixable.isEmpty || !project.isEmpty else { return nil }
        let blocking = fixable.count { $0.level == .blocksReview }
        var parts: [String] = []
        if !fixable.isEmpty {
            let named = fixable.prefix(reviewRisksNamed).map { "\($0.title) (guideline \($0.guideline), riskId \($0.id))" }
            let more = fixable.count > reviewRisksNamed ? " and \(fixable.count - reviewRisksNamed) more" : ""
            parts.append("\(fixable.count == 1 ? "1 risk" : "\(fixable.count) risks") with a fix to propose: \(named.joined(separator: "; "))\(more)")
        }
        if !project.isEmpty {
            parts.append("project checks nobody answered: \(project.map(\.mcpName).joined(separator: ", "))")
        }
        let subject = inputs.version?.id ?? "app"
        return WatchSignal(
            kind: .appReviewRisk, appID: inputs.appID, subject: subject, value: Double(fixable.count + project.count),
            numbers: ["risks": Double(fixable.count), "blocking": Double(blocking), "project": Double(project.count)],
            summary: "Atlas's App Review checks found, for \(inputs.appName): \(parts.joined(separator: "; "))."
        )
    }

    /// Editable events whose card shows within `eventWindow` with
    /// something missing.
    static func events(_ inputs: WatchInputs) -> [WatchSignal] {
        inputs.events.compactMap { event in
            guard event.isEditable, let deadline = event.deadline, deadline > inputs.now,
                  deadline.timeIntervalSince(inputs.now) <= eventWindow, event.issueCount > 0
            else { return nil }
            let days = max(1, Int((deadline.timeIntervalSince(inputs.now) / 86400).rounded(.up)))
            var parts: [String] = []
            if !event.missingForReview.isEmpty { parts.append("missing for App Review: \(event.missingForReview.joined(separator: ", "))") }
            if !event.reviewWarnings.isEmpty { parts.append("App Review warnings: \(event.reviewWarnings.joined(separator: ", "))") }
            if !event.missingLanguages.isEmpty { parts.append("not written in \(event.missingLanguages.joined(separator: ", "))") }
            let day = deadline.formatted(.iso8601.year().month().day())
            return WatchSignal(
                kind: .eventDeadline, appID: inputs.appID, subject: event.id, value: Double(event.issueCount),
                numbers: ["issues": Double(event.issueCount)],
                summary: "In-App Event “\(event.name)” (eventId \(event.id)) shows its card in \(days == 1 ? "1 day" : "\(days) days"), "
                    + "on \(day): \(parts.joined(separator: "; ")).",
                deadline: deadline
            )
        }
    }

    /// What's New missing in the version being prepared, with commits
    /// since the last release to write it from.
    static func whatsNew(_ inputs: WatchInputs) -> WatchSignal? {
        guard let version = inputs.version, version.phase == .prepare, let whatsNew = inputs.whatsNew, !whatsNew.missing.isEmpty,
              let commits = inputs.commits, commits.count > 0
        else { return nil }
        let missing = whatsNew.missing.count
        let since = commits.tag.map { "since \($0)" } ?? "in the recent history"
        return WatchSignal(
            kind: .whatsNewMissing, appID: inputs.appID, subject: version.versionString, value: Double(missing),
            numbers: ["missing": Double(missing)],
            summary: "Version \(version.versionString) is in Prepare for Submission and What's New is missing in \(missing) of "
                + "\(whatsNew.languages) languages (\(whatsNew.missing.joined(separator: ", "))); the project has "
                + "\(commits.count == 1 ? "1 commit" : "\(commits.count) commits") \(since)."
        )
    }

    /// The newest version crashes clearly more than the one before.
    static func crashes(_ inputs: WatchInputs) -> WatchSignal? {
        guard let report = inputs.stability, report.isWorse, let times = report.times, let previous = report.previous else { return nil }
        let rate = report.latest.perThousand.map { " (\(format($0)) per 1,000 sessions)" } ?? ""
        return WatchSignal(
            kind: .crashesWorse, appID: inputs.appID, subject: report.latest.version, value: times,
            numbers: ["times": times],
            summary: "Version \(report.latest.version) crashes \(format(times))× as often as \(previous.version) on the same days\(rate); "
                + "Apple's crash reports are a sample of people who share analytics."
        )
    }

    /// Reviews since the release: the average fell, or many 1–2 stars that
    /// no group holds yet.
    static func reviews(_ inputs: WatchInputs) -> WatchSignal? {
        guard let split = split(inputs), split.after.count >= reviewsNeeded else { return nil }
        let average = mean(split.after)
        let low = split.after.filter(\.isLow)
        let previous = split.before.count >= reviewsBeforeNeeded ? mean(split.before) : nil
        let dropped = previous.map { $0 - average >= ratingDrop } ?? false
        let manyLow = low.count >= lowReviewsNeeded && Double(low.count) / Double(split.after.count) >= lowShare
        guard dropped || manyLow else { return nil }
        // Already grouped: a group holds most of the low ones.
        let grouped = Set(inputs.themes.flatMap(\.reviewIDs))
        if !low.isEmpty, low.count(where: { !grouped.contains($0.id) }) * 2 < low.count { return nil }
        let against = previous.map { ", against \(format($0))★ in the \(split.before.count) before" } ?? ""
        return WatchSignal(
            kind: .reviewsAfterRelease, appID: inputs.appID, subject: split.version, value: Double(split.after.count),
            numbers: ["low": Double(low.count), "average": average],
            summary: "Since version \(split.version): \(split.after.count) new reviews, \(low.count) of them 1–2 stars, "
                + "average \(format(average))★\(against)."
        )
    }

    /// The reviews of the version out now, and those of the 90 days before
    /// it: by the version they're about, else by the day it went out.
    private static func split(_ inputs: WatchInputs) -> (version: String, after: [AppReview], before: [AppReview])? {
        if let current = inputs.reviewedVersion {
            let after = inputs.reviews.filter { $0.version == current }
            let start = after.map(\.date).min() ?? inputs.now
            let before = inputs.reviews.filter { $0.version != current && $0.date < start && $0.date >= start.addingTimeInterval(-reviewsBeforeWindow) }
            return (current, after, before)
        }
        guard let version = inputs.version, let since = version.liveSince else { return nil }
        let after = inputs.reviews.filter { $0.date >= since }
        let before = inputs.reviews.filter { $0.date < since && $0.date >= since.addingTimeInterval(-reviewsBeforeWindow) }
        return (version.versionString, after, before)
    }

    private static func mean(_ reviews: [AppReview]) -> Double {
        reviews.isEmpty ? 0 : Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
    }

    /// One decimal, the same on every Mac: "3.2".
    static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }
}
