//
//  BackgroundWork.swift
//  Atlas
//

import Foundation
import Observation

/// What Atlas does while nobody is looking, for the menu bar: the jobs
/// running now (a push, Autopilot, Suggest Everything, a check), what
/// waits on the person, and the checks it makes on its own every
/// `CheckInterval` (reviews, version status, analytics reports) unless
/// background work is paused.
///
/// It lives above the main window, which keeps it fed: the library's apps
/// (for names and the "Needs you" lines), how to check, and how to open a
/// place. The window stays alive when it's closed (`MainWindowKeeper`
/// hides it), so all of that keeps working with no window on screen.
@MainActor
@Observable
final class BackgroundWork {
    /// The library's apps, set by the main window once it has them.
    var library: [StoreApp] = []
    /// One pass over App Store Connect: the app list, versions in flight,
    /// due analytics reports, stale reviews. Returns what went wrong when
    /// Apple refused the key or couldn't be reached, else nil.
    var checkHandler: (@MainActor () async -> String?)?
    /// Opens a place in the main window (it's on screen by then).
    var openHandler: (@MainActor (BackgroundDestination) -> Void)?
    /// Whether the account is on Free, where suggested review replies
    /// don't exist.
    var isFree: @MainActor () -> Bool = { false }

    private(set) var isPaused: Bool {
        didSet { defaults?.set(isPaused, forKey: Key.isPaused) }
    }

    private(set) var lastCheckedAt: Date? {
        didSet { defaults?.set(lastCheckedAt, forKey: Key.lastCheckedAt) }
    }

    private(set) var isChecking = false
    /// Why the last check couldn't reach App Store Connect; nil once one
    /// did.
    private(set) var connectionProblem: String?

    private let push: PushController
    private let changes: ChangeQueue
    private let suggestions: FieldSuggestionStore
    private let preferences: AppPreferences
    private let autopilot: AutopilotCenter
    private let reviews: ReviewsStore
    private let releases: ReleaseStore
    private let analytics: AnalyticsStore
    private let artwork: EventArtworkStudio
    private let defaults: UserDefaults?
    private let now: () -> Date
    private var loop: Task<Void, Never>?

    /// An Autopilot run whose assistant has sent nothing for this long
    /// isn't counted as running: its Claude Code most likely stopped.
    static let autopilotQuietLimit: TimeInterval = 20 * 60
    /// How often the loop looks whether a check is due.
    static let tick: Duration = .seconds(30)

    init(
        push: PushController,
        changes: ChangeQueue,
        suggestions: FieldSuggestionStore,
        preferences: AppPreferences,
        autopilot: AutopilotCenter = .shared,
        reviews: ReviewsStore = .shared,
        releases: ReleaseStore = .shared,
        analytics: AnalyticsStore = .shared,
        artwork: EventArtworkStudio = .shared,
        defaults: UserDefaults? = .standard,
        now: @escaping () -> Date = { .now }
    ) {
        self.push = push
        self.changes = changes
        self.suggestions = suggestions
        self.preferences = preferences
        self.autopilot = autopilot
        self.reviews = reviews
        self.releases = releases
        self.analytics = analytics
        self.artwork = artwork
        self.defaults = defaults
        self.now = now
        isPaused = defaults?.bool(forKey: Key.isPaused) ?? false
        lastCheckedAt = defaults?.object(forKey: Key.lastCheckedAt) as? Date
    }

    // MARK: - What's happening

    /// Work that should finish before Atlas quits: a push, a screenshot
    /// push, an Autopilot run, Suggest Everything.
    var isBusy: Bool {
        push.isRunning || push.screenshots.run?.isRunning == true || !activeAutopilotRuns(now: now()).isEmpty
            || suggestions.run?.isRunning == true || !artwork.makingRuns.isEmpty
    }

    var snapshot: MenuBarSnapshot { snapshot(at: now()) }

    func snapshot(at date: Date) -> MenuBarSnapshot {
        MenuBarSnapshot(
            jobs: jobs(at: date),
            needs: needs,
            checkLine: BackgroundCheckSchedule.statusLine(
                last: lastCheckedAt, interval: preferences.checkInterval, isPaused: isPaused, now: date
            ),
            reviewPushCount: changes.totalCount,
            isPaused: isPaused,
            connectionProblem: connectionProblem
        )
    }

    var iconState: MenuBarIconState { snapshot.state }

    /// The "Needs you" lines, every app's.
    var needs: [BackgroundNeed] {
        let facts = library.map { app in
            let findings = analytics.findings(for: app.id)
            let newFindings = analytics.newFindingCount(for: app.id)
            let snapshot = releases.snapshot(for: app.id)
            return BackgroundAppFacts(
                appID: app.id,
                appName: app.name,
                autopilotTurn: autopilot.run(for: app.id).flatMap { BackgroundNeedsBuilder.turn(for: $0.stage) },
                openSuggestions: suggestions.toReview(for: app.id).count,
                approvedVersion: snapshot?.phase == .pendingDeveloperRelease ? snapshot?.versionString : nil,
                reviewReplies: isFree() ? 0 : reviews.suggestionCount(for: app.id),
                newFindings: newFindings,
                firstFindingTitle: newFindings > 0 ? findings.open.first(where: findings.isNew)?.title : nil,
                readyArtwork: artwork.readyRuns.filter { $0.appID == app.id }.map { run in
                    BackgroundAppFacts.ReadyArtwork(eventID: run.eventID, eventName: run.eventName, count: run.concepts.count)
                }
            )
        }
        return BackgroundNeedsBuilder.needs(for: facts, namesApps: library.count > 1)
    }

    func jobs(at date: Date) -> [BackgroundJob] {
        var jobs: [BackgroundJob] = []
        if push.isRunning {
            let parts = [
                String(localized: "\(push.finishedCount) of \(push.totalCount) changes"),
                singleAppName(Set(push.items.map(\.change.appID))),
                push.startedAt.flatMap { TimeLeftEstimate.text(startedAt: $0, fraction: push.progress, now: date) },
            ]
            jobs.append(BackgroundJob(
                id: "push", kind: .push, title: String(localized: "Pushing to App Store Connect"),
                fraction: push.progress, detail: parts.compactMap(\.self).joined(separator: " · ")
            ))
        }
        if let run = push.screenshots.run, run.isRunning {
            let parts = [
                String(localized: "\(run.finishedCount) of \(run.totalCount) screenshots"),
                singleAppName(Set(run.appIDs)),
                TimeLeftEstimate.text(startedAt: run.date, fraction: run.progress, now: date),
            ]
            jobs.append(BackgroundJob(
                id: "screenshot-push", kind: .screenshotPush, title: String(localized: "Pushing screenshots"),
                fraction: run.progress, detail: parts.compactMap(\.self).joined(separator: " · ")
            ))
        }
        for run in activeAutopilotRuns(now: date) {
            let progress = GuidedRunProgress.make(run, now: date)
            let name = library.count > 1 ? appName(run.appID) : nil
            jobs.append(BackgroundJob(
                id: "autopilot-\(run.appID)", kind: .autopilot, title: String(localized: "Autopilot · \(progress.title)"),
                fraction: progress.fraction, detail: [name, progress.line.isEmpty ? nil : progress.line].compactMap(\.self).joined(separator: " · ")
            ))
        }
        if let run = suggestions.run, run.isRunning {
            jobs.append(BackgroundJob(
                id: "suggest-everything", kind: .suggestEverything, title: String(localized: "Suggest Everything"),
                fraction: run.fraction, detail: [appName(run.appID), run.progressText].joined(separator: " · ")
            ))
        }
        for run in artwork.makingRuns {
            let ready = run.designedCount
            let detail = run.revising.map { String(localized: "Changing “\($0.name)”") }
                ?? String(localized: "\(ready) of \(run.expectedCount) concepts ready")
            jobs.append(BackgroundJob(
                id: "event-artwork-\(run.appID)-\(run.eventID)", kind: .eventArtwork,
                title: String(localized: "Claude · \(run.eventName)"),
                fraction: run.revisingID != nil ? nil : min(1, (Double(ready) + 0.35) / Double(max(1, run.expectedCount))),
                detail: [library.count > 1 ? appName(run.appID) : nil, detail].compactMap(\.self).joined(separator: " · ")
            ))
        }
        if isChecking {
            jobs.append(BackgroundJob(
                id: "check", kind: .check, title: String(localized: "Checking App Store Connect"),
                fraction: nil, detail: String(localized: "Reviews, version status and analytics reports")
            ))
        }
        return jobs
    }

    /// Runs whose assistant is at work: a running stage, not finished, and
    /// heard from lately.
    private func activeAutopilotRuns(now date: Date) -> [AutopilotRun] {
        autopilot.runs.values
            .filter { run in
                guard run.stage.isRunning, run.finishedAt == nil else { return false }
                guard let last = run.lastActivityAt ?? run.startedAt else { return true }
                return date.timeIntervalSince(last) < Self.autopilotQuietLimit
            }
            .sorted { $0.appID < $1.appID }
    }

    private func appName(_ id: StoreApp.ID) -> String {
        library.first { $0.id == id }?.name ?? push.appName(id)
    }

    /// The app's name when the work is all for one app.
    private func singleAppName(_ ids: Set<StoreApp.ID>) -> String? {
        guard ids.count == 1, let id = ids.first else { return nil }
        return appName(id)
    }

    // MARK: - Checking

    /// When the next check is due; nil while paused or with "Only when I
    /// ask".
    var nextCheckAt: Date? {
        BackgroundCheckSchedule.nextCheck(after: lastCheckedAt, interval: preferences.checkInterval, isPaused: isPaused, now: now())
    }

    /// Starts the loop that checks whenever one is due. Once.
    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if BackgroundCheckSchedule.isDue(after: lastCheckedAt, interval: preferences.checkInterval, isPaused: isPaused, now: now()) {
                    await check()
                }
                try? await Task.sleep(for: Self.tick)
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    /// The last key was removed: nothing to check or open until another
    /// main window attaches.
    func detach() {
        library = []
        checkHandler = nil
        openHandler = nil
        connectionProblem = nil
    }

    /// Check Now (⌘R in the menu): checks at once, paused or not. Does
    /// nothing while a check runs or before the main window can check.
    func check() async {
        guard !isChecking, let checkHandler else { return }
        isChecking = true
        defer { isChecking = false }
        connectionProblem = await checkHandler()
        lastCheckedAt = now()
    }

    /// Pause Background Work / Resume Background Work.
    func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    // MARK: - Opening

    func open(_ destination: BackgroundDestination) {
        openHandler?(destination)
    }

    private enum Key {
        static let isPaused = "backgroundWorkPaused"
        static let lastCheckedAt = "lastBackgroundCheck"
    }
}
