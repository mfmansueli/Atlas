//
//  ReleaseViewModel.swift
//  Atlas
//

import Foundation
import Observation

/// One app's version on its way to the App Store: what the Overview's
/// version card, the Submit sheet and the sidebar's footer show, and the
/// writes behind their buttons. Reading is cheap and kept; every write is
/// one the person asked for.
@MainActor
@Observable
final class ReleaseViewModel {
    let app: StoreApp
    let services: WorkspaceServices
    let store: ReleaseStore
    let queue: ChangeQueue
    let suggestions: FieldSuggestionStore
    let push: PushController

    // MARK: - Loaded

    private(set) var status: ReleaseStatus?
    private(set) var hasLoaded = false
    private(set) var isLoading = false
    /// The Submit sheet is reading the version and its builds again.
    private(set) var isRefreshingBuilds = false
    private(set) var errorMessage: String?
    /// The version's store page: its languages and What's New.
    private(set) var content: StorePageContent?
    /// The app's In-App Events, for the ones that go with the version.
    private(set) var events: [InAppEvent] = []

    // MARK: - Submit sheet

    var options = SubmissionOptions()
    var isSubmitting = false
    /// "Pushing 5 changes…", "Submitting…".
    var submitProgress: String?
    var submitError: String?
    /// The last Submit that didn't go, behind `submitError`: reading the
    /// events again takes it away once what it named is fixed, or marks it
    /// as the last attempt's.
    var submitFailure: SubmitFailureNote?

    // MARK: - Card actions

    /// The write in flight.
    var busyAction: ReleaseAction?
    /// The action waiting for the person's confirmation.
    var confirming: ReleaseAction?
    var actionError: String?

    /// The Store Page's model, loaded, to accept a What's New suggestion
    /// exactly as the Store Page does. Set by the window.
    @ObservationIgnored var storePageModel: (@MainActor () async -> StorePageViewModel?)?
    /// Says something in the window's toast.
    @ObservationIgnored var onMessage: @MainActor (String) -> Void = { _ in }
    /// The version's state changed in App Store Connect: reload what
    /// depends on it.
    @ObservationIgnored var onChanged: @MainActor () -> Void = {}
    @ObservationIgnored var now: () -> Date = { .now }
    /// The checks of events' deep links, for the Submit sheet.
    @ObservationIgnored var eventsStore: InAppEventsStore = .shared
    /// What the app's project claims, for the events' deep links.
    @ObservationIgnored var linkClaims: ProjectLinkClaimsCenter = .shared
    /// The one more read once dates just pushed are no longer trusted.
    @ObservationIgnored let readAgain = InAppEventReadAgain()
    /// What assistants proposed for the version over MCP, waiting on the
    /// card for the person's Confirm.
    @ObservationIgnored var proposals: ReleaseProposalStore = .shared

    /// `events` keeps the checks of the events' deep links, as In-App
    /// Events does.
    init(
        app: StoreApp, services: WorkspaceServices, store: ReleaseStore, queue: ChangeQueue, suggestions: FieldSuggestionStore, push: PushController,
        events: InAppEventsStore = .shared
    ) {
        self.app = app
        self.services = services
        self.store = store
        self.queue = queue
        self.suggestions = suggestions
        self.push = push
        eventsStore = events
    }

    // MARK: - Reading

    var phase: ReleasePhase? { status?.phase }

    /// "1.4".
    var versionString: String { status?.version.versionString ?? "" }

    /// "Lumen Journal 1.4".
    var versionName: String { "\(app.name) \(versionString)" }

    /// For the sidebar's footer and the toolbar's title: the status once
    /// read, else what was last seen.
    var summary: VersionStatusSummary? {
        if let status { return VersionStatusSummary(versionString: status.version.versionString, phase: status.phase) }
        return store.snapshot(for: app.id).map { VersionStatusSummary(versionString: $0.versionString, phase: $0.phase) }
    }

    /// Changes of this app waiting in Review & Push.
    var pendingCount: Int { queue.count(for: app.id) }

    // MARK: - Loading

    /// Reads the version, its builds and submission, its store page and
    /// the app's events. `platform` follows the Store Page's version.
    func load(platform: String? = nil) async {
        guard !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }
        do {
            let loaded = try await services.release.status(for: app, platform: platform ?? status?.version.platform)
            status = loaded
            errorMessage = nil
            if let loaded {
                if let moved = store.note(loaded, for: app.id) { announce(moved, version: loaded.version.versionString) }
                await loadDetails(of: loaded)
            }
        } catch {
            errorMessage = AppleErrorCopy(String(localized: "The version didn’t load.", comment: "kind:error"), error: error).text
        }
    }

    /// Reads the version again for the Submit sheet: its builds, which
    /// change while Apple processes a new upload (before, the list was
    /// read once when the app was opened, and a build uploaded since never
    /// showed), and after a Submit that stopped halfway, its phased
    /// release, attached build and submission. Keeps what the person
    /// chose: the build they picked, unless it can't be chosen any more,
    /// and every other answer. A version that moved on (submitted or
    /// replaced elsewhere) loads again.
    func refreshStatus() async {
        guard !isLoading, !isRefreshingBuilds, let current = status else { return }
        isRefreshingBuilds = true
        defer { isRefreshingBuilds = false }
        guard let loaded = try? await services.release.status(for: app, platform: current.version.platform) else { return }
        guard loaded.version.id == current.version.id, loaded.phase == current.phase else {
            isRefreshingBuilds = false
            await load(platform: current.version.platform)
            return
        }
        let pickedByPerson = options.buildID != Self.defaultBuildID(in: current)
        status = loaded
        let stillChoosable = loaded.builds.contains { $0.id == options.buildID && $0.isSelectable }
        guard !pickedByPerson || !stillChoosable else { return }
        options.buildID = Self.defaultBuildID(in: loaded)
        if let known = knownEncryption { options.encryption = known }
    }

    /// The build the sheet starts with: the attached one, else the newest
    /// that's ready.
    static func defaultBuildID(in status: ReleaseStatus) -> ReleaseBuild.ID? {
        let selectable = status.builds.filter(\.isSelectable)
        return selectable.first { $0.id == status.attachedBuildID }?.id ?? selectable.first?.id
    }

    /// What only the card before submitting and the sheet need: the
    /// events (also while a submission carries some), and the texts. The
    /// sheet's choices start over from App Store Connect's, except while a
    /// Submit runs (a push it makes reads the version again midway).
    private func loadDetails(of status: ReleaseStatus) async {
        let isBeforeSubmitting = status.phase == .prepare || status.phase == .rejected
        if isBeforeSubmitting || status.submission?.eventIDs.isEmpty == false, await readEvents() {
            reviewLastFailure()
        }
        guard isBeforeSubmitting else { return }
        content = await (try? services.storePage.content(for: app, versionID: status.version.id)) ?? content
        if !isSubmitting { resetOptions() }
    }

    /// The sheet's choices as App Store Connect has them: the attached
    /// build (else the newest that's ready), how the version is released,
    /// the encryption answer already given, and the events ticked before.
    func resetOptions() {
        guard let status else { return }
        var options = SubmissionOptions()
        options.buildID = Self.defaultBuildID(in: status)
        options.timing = status.version.timing.kind
        options.releaseDate = status.version.timing.date ?? defaultReleaseDate
        options.pushesChanges = true
        let kept = Set(store.eventIDs(for: app.id))
        let inSubmission = Set(status.submission?.eventIDs ?? [])
        options.eventIDs = Set(offeredEvents.map(\.id)).intersection(kept.union(inSubmission))
        self.options = options
        self.options.encryption = knownEncryption
    }

    /// A week from now, at 9:00.
    private var defaultReleaseDate: Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: 7, to: now()) ?? now()
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
    }

    /// The answer the chosen build carries, else the one kept in App
    /// Information → Export Compliance.
    var knownEncryption: EncryptionAnswer? {
        EncryptionAnswer.known(saved: EncryptionAnswer(services.appInformation.notes.notes(for: app.id).exportAnswers), build: selectedBuild)
    }

    var selectedBuild: ReleaseBuild? {
        status?.builds.first { $0.id == options.buildID }
    }

    /// Reads the events again when the sheet opens: a deep link, art or
    /// dates added on the event's page and pushed since show there, and the
    /// last Submit's failure goes once that fixed it.
    func refreshEvents() async {
        guard await readEvents() else { return }
        reviewLastFailure()
    }

    /// Reads the app's events; keeps the ones read before when it fails.
    /// Dates pushed in the last two minutes stand over a read that doesn't
    /// show them yet, and the events are read once more after
    /// (`InAppEventPushedDates`). The suggestions kept for them are settled
    /// the way In-App Events does (`InAppEventsStore.noteRead`).
    @discardableResult
    func readEvents() async -> Bool {
        guard let read = try? await services.inAppEvents.events(for: app) else { return false }
        let settled = InAppEventPushedDates(appID: app.id, history: push.history, now: now()).settle(read)
        events = settled.events
        eventsStore.noteRead(settled.events, for: app.id)
        readAgain.schedule(at: settled.readAgainAt, now: now()) { [weak self] in await self?.refreshEvents() }
        return true
    }

    /// After the events are read again, outside a Submit: the last
    /// Submit's failure goes when what it named is fixed (dates that had
    /// passed, moved ahead), else it shows as the last attempt's.
    func reviewLastFailure() {
        guard !isSubmitting, var note = submitFailure else { return }
        if note.isCleared(by: events, now: now()) {
            submitFailure = nil
            submitError = nil
            return
        }
        guard !note.isFromLastAttempt else { return }
        note.isFromLastAttempt = true
        submitFailure = note
        submitError = note.shownText(now: now())
    }

    /// The events ticked to go with the version, for the card and for
    /// In-App Events' "Goes with 1.4".
    var eventsGoingWithVersion: [InAppEvent] {
        let inSubmission = Set(status?.submission?.eventIDs ?? [])
        let ticked = phase == .prepare || phase == .rejected ? Set(store.eventIDs(for: app.id)) : []
        return events.filter { inSubmission.contains($0.id) || (ticked.contains($0.id) && $0.canSubmit(now: now())) }
    }

    // MARK: - Telling

    /// The version moved since Atlas last looked.
    private func announce(_ phase: ReleasePhase, version: String) {
        guard let text = Self.announcement(phase, version: version, appName: app.name) else { return }
        onMessage(text)
        ReleaseNotifier.shared.post(text, appName: app.name, appID: app.id)
    }

    /// "Lumen Journal 1.4 is approved and waiting for you."
    static func announcement(_ phase: ReleasePhase, version: String, appName: String) -> String? {
        let name = "\(appName) \(version)"
        switch phase {
        case .prepare, .waitingForReview: return nil
        case .inReview: return String(localized: "App Review is looking at \(name).")
        case .rejected: return String(localized: "App Review sent \(name) back. Its message is in App Store Connect.")
        case .pendingDeveloperRelease: return String(localized: "\(name) is approved and waiting for you to release it.")
        case .pendingAppleRelease: return String(localized: "\(name) is approved. Apple releases it.")
        case .phased: return String(localized: "\(name) is on the App Store, rolling out over 7 days.")
        case .live: return String(localized: "\(name) is on the App Store for everyone.")
        }
    }

    #if DEBUG
    /// DEBUG scenes and tests: the status as if just read.
    func load(status: ReleaseStatus, content: StorePageContent?, events: [InAppEvent]) {
        self.status = status
        self.content = content
        self.events = events
        hasLoaded = true
        store.note(status, for: app.id)
        resetOptions()
    }
    #endif
}
