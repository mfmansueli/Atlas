//
//  ReleaseViewModel+Card.swift
//  Atlas
//

import Foundation

// The Overview's version card: what it says in each phase, the checks
// before submitting and the steps after.
extension ReleaseViewModel {
    /// "Lumen Journal 1.4 is almost ready for App Review".
    var cardTitle: String {
        let version = versionString
        switch phase {
        case nil: return ""
        case .prepare:
            return blockers.isEmpty
                ? String(localized: "\(versionName) is ready for App Review")
                : String(localized: "\(versionName) is almost ready for App Review")
        case .waitingForReview: return String(localized: "\(version) is waiting for App Review")
        case .inReview: return String(localized: "App Review is looking at \(version)")
        case .rejected: return String(localized: "App Review sent \(version) back")
        case .pendingDeveloperRelease: return String(localized: "\(version) is approved and waiting for you")
        case .pendingAppleRelease: return String(localized: "\(version) is approved")
        case let .phased(_, isPaused):
            return isPaused ? String(localized: "The rollout of \(version) is paused") : String(localized: "\(version) is rolling out")
        case .live: return String(localized: "\(version) is on the App Store")
        }
    }

    var cardSubtitle: String {
        let version = versionString
        switch phase {
        case nil: return ""
        case .prepare:
            return String(localized: "Everything below goes to Apple in one submission.")
        case .waitingForReview:
            return String(localized: "Most apps are reviewed within a day. Atlas tells you when it changes.")
        case .inReview:
            return String(localized: "Nothing to do until it finishes.")
        case .rejected:
            return String(localized: """
            Apple’s message is in App Store Connect; this key can’t read it. Fix what it asks for, then submit again. The rest of \
            the submission stays as it is.
            """)
        case .pendingDeveloperRelease:
            return String(localized: "You chose to release it yourself. It stays ready for up to 90 days.")
        case .pendingAppleRelease:
            guard let date = status?.version.timing.date, date > now() else { return String(localized: "Apple is releasing it.") }
            return String(localized: "Apple releases it on \(date.formatted(date: .abbreviated, time: .shortened)).")
        case let .phased(day, isPaused):
            let share = PhasedRelease.percentage(day: day)
            return isPaused
                ? String(localized: "Paused on day \(day). Automatic updates stop until you resume; anyone can still download \(version) from the App Store. You can pause for up to 30 days in total.")
                : String(localized: "\(share)% of people with automatic updates have \(version) so far. Anyone can download it from the App Store today.")
        case .live:
            return String(localized: "Everyone gets it now.")
        }
    }

    /// The pill's color.
    var pillStyle: PillStyle {
        switch phase {
        case nil, .prepare: .neutral
        case .waitingForReview, .inReview: .accent
        case .rejected: .danger
        case .pendingDeveloperRelease, .pendingAppleRelease, .live: .decrease
        case let .phased(_, isPaused): isPaused ? .warning : .decrease
        }
    }

    // MARK: - Before submitting

    /// What goes to App Review, and what's missing.
    var checks: [ReleaseCheck] {
        var checks = [buildCheck]
        if let whatsNew = whatsNewCheck { checks.append(whatsNew) }
        checks.append(changesCheck)
        if status?.isReviewInformationComplete == false {
            checks.append(ReleaseCheck(
                kind: .reviewInformation, isOK: false, title: String(localized: "App Review information is incomplete"),
                detail: String(localized: "App Review needs a contact, and the demo account when sign-in is required"), buttonTitle: String(localized: "Open")
            ))
        }
        checks += eventsGoingWithVersion.map { event in
            ReleaseCheck(
                kind: .event, isOK: true, title: String(localized: "In-App Event “\(Self.displayName(of: event))”"),
                detail: String(localized: "Goes with \(versionString) · \(ReviewText.languages(event.localizations.count))"),
                buttonTitle: String(localized: "Open"), eventID: event.id
            )
        }
        return checks
    }

    /// The event's own name, else its reference name.
    static func displayName(of event: InAppEvent) -> String {
        let name = event.primaryLocalization?.name ?? ""
        return name.isEmpty ? event.referenceName : name
    }

    private var buildCheck: ReleaseCheck {
        guard let build = selectedBuild else {
            let processing = status?.builds.contains { $0.processing == .processing } ?? false
            return ReleaseCheck(
                kind: .build, isOK: false, title: String(localized: "No build yet"),
                detail: processing
                    ? String(localized: "Apple is still processing the one you uploaded")
                    : String(localized: "Upload one from Xcode; it shows here once Apple has processed it")
            )
        }
        return ReleaseCheck(kind: .build, isOK: true, title: String(localized: "Build \(build.title(version: versionString))"), detail: build.detail)
    }

    /// Nil for a first version, which has no What's New.
    private var whatsNewCheck: ReleaseCheck? {
        let rows = whatsNewRows
        guard !rows.isEmpty else { return nil }
        let missing = rows.filter(\.isMissing)
        guard let first = missing.first else {
            return ReleaseCheck(
                kind: .whatsNew, isOK: true, title: String(localized: "What’s New in \(ReviewText.languages(rows.count))"),
                detail: String(localized: "Written or accepted")
            )
        }
        let suggested = missing.contains { if case .suggested = $0.state { true } else { false } }
        let names = missing.count == 1
            ? String(localized: "\(first.locale.name) is missing")
            : String(localized: "\(first.locale.name) and \(missing.count - 1) more are missing")
        return ReleaseCheck(
            kind: .whatsNew, isOK: false, title: String(localized: "What’s New in \(rows.count - missing.count) of \(ReviewText.languages(rows.count))"),
            detail: suggested ? String(localized: "\(names); a suggestion is waiting") : names, buttonTitle: String(localized: "Review")
        )
    }

    private var changesCheck: ReleaseCheck {
        let pending = pendingCount
        guard pending > 0 else {
            return ReleaseCheck(
                kind: .changes, isOK: true, title: String(localized: "Store Page, Screenshots and Pricing are pushed"),
                detail: String(localized: "What App Review sees is what you edited")
            )
        }
        return ReleaseCheck(
            kind: .changes, isOK: false,
            title: pending == 1 ? String(localized: "1 change not pushed yet") : String(localized: "\(pending) changes not pushed yet"),
            detail: String(localized: "You can push them with the submission")
        )
    }

    // MARK: - After submitting

    /// Submitted → Waiting for Review → In Review → Approved → On the App
    /// Store, with when each was seen.
    var steps: [ReleaseStep] {
        guard let status, let phase else { return [] }
        let current: Int = switch phase {
        case .prepare: -1
        case .waitingForReview: 1
        case .inReview, .rejected: 2
        case .pendingDeveloperRelease, .pendingAppleRelease: 3
        case .phased, .live: 4
        }
        let titles = [
            String(localized: "Submitted"), String(localized: "Waiting for Review"),
            phase == .rejected ? String(localized: "Rejected") : String(localized: "In Review"),
            String(localized: "Approved"), String(localized: "On the App Store"),
        ]
        let keys = ["waiting", "waiting", phase == .rejected ? "rejected" : "review", phase == .pendingDeveloperRelease ? "pending" : "approved", "phased"]
        return titles.indices.map { index in
            let state: ReleaseStep.State = if phase == .rejected, index == 2 {
                .rejected
            } else if index < current || phase == .live {
                .done
            } else {
                index == current ? .current : .upcoming
            }
            return ReleaseStep(id: index, title: titles[index], detail: stepDetail(index, key: keys[index], state: state, status: status), state: state)
        }
    }

    private func stepDetail(_ index: Int, key: String, state: ReleaseStep.State, status: ReleaseStatus) -> String {
        let versionID = status.version.id
        switch index {
        case 0:
            return (status.submission?.submitted ?? store.date(of: "waiting", versionID: versionID)).map(Self.moment) ?? ""
        case 1 where state == .current:
            return String(localized: "Usually about a day")
        case 4:
            if case let .phased(day, _) = status.phase { return String(localized: "Day \(day) of \(PhasedRelease.dayCount)") }
            // A date kept from an earlier submission isn't this one's.
            guard state != .upcoming else { return "" }
            return (store.date(of: "live", versionID: versionID) ?? store.date(of: "phased", versionID: versionID)).map(Self.day) ?? ""
        default:
            guard state != .upcoming else { return "" }
            let date = store.date(of: key, versionID: versionID) ?? (index == 3 ? store.date(of: "approved", versionID: versionID) : nil)
            return date.map(Self.day) ?? ""
        }
    }

    /// "Nov 16, 10:42".
    static func moment(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    /// "Nov 17".
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// The header's "where": "Prepare for Submission", "Phased release,
    /// day 3 of 7"…
    var headerState: String? {
        switch phase {
        case nil: nil
        case .prepare: String(localized: "Prepare for Submission")
        case .waitingForReview: String(localized: "Waiting for Review")
        case .inReview: String(localized: "In Review")
        case .rejected: String(localized: "Rejected by App Review")
        case .pendingDeveloperRelease: String(localized: "Approved, waiting for you to release it")
        case .pendingAppleRelease: String(localized: "Approved")
        case let .phased(day, isPaused): Self.phasedState(day: day, isPaused: isPaused)
        case .live: String(localized: "Ready for Distribution")
        }
    }

    private static func phasedState(day: Int, isPaused: Bool) -> String {
        if isPaused { return String(localized: "Phased release paused") }
        return String(localized: "Phased release, day \(day) of \(PhasedRelease.dayCount)")
    }
}
