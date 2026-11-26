//
//  PushController.swift
//  Atlas
//

import Foundation
import Observation
import OSLog

/// Sends reviewed changes to App Store Connect, a few at once
/// (`PushSchedule`: those that depend on each other still go in order), and
/// keeps the progress list Review & Push shows. It lives above the sheet, so
/// a push keeps going while the person works elsewhere.
///
/// Each change is checked first when it has a `ConflictCheck`; a value that
/// changed in App Store Connect isn't overwritten but goes back to review.
/// Pushed changes leave the queue and are recorded in `PushHistory`.
///
/// A change sends its `pushRequests` (its own, then its option's when that's
/// on). Changes with the same `mergeKey` (an age rating declaration's
/// answers) go out together as one `PATCH`, since App Store Connect only
/// takes that resource whole. Placeholders are filled in just before each request goes: a
/// `{createdID}` with the ID an earlier `POST` of the same change returned,
/// a `{secret:…}` from `secrets`. A new Store Page locale App Store Connect
/// refuses as a duplicate goes onto the localization that's there instead
/// (`ExistingLocalizationUpdate`).
@MainActor
@Observable
final class PushController {
    enum Phase: Hashable, Sendable {
        case idle
        case running
        case finished
    }

    private(set) var phase: Phase = .idle
    private(set) var items: [PushItem] = []
    /// When the push running now started, for the menu bar's "about 1 min
    /// left".
    private(set) var startedAt: Date?
    /// What the workspace banner shows; nil when there's nothing to report.
    private(set) var notice: PushNotice?
    /// Whether the Mac has a network path; nil until it's known
    /// (`watchConnection`), and in tests.
    var isOnline: Bool?
    /// Set by the session: the API client, or a simulation.
    var transport: (any PushTransport)?
    /// The app names Activity records carry.
    var appName: (StoreApp.ID) -> String = { $0 }
    /// Pricing's price history: each pushed subscription price change is
    /// recorded there.
    @ObservationIgnored var priceHistory = PriceChangeHistoryStore.shared
    /// Called with the apps whose values changed, so their numbers reload:
    /// the main window runs Refresh after every push that changed
    /// something (README-DS §15), screenshots and extras included.
    var onPushed: (Set<StoreApp.ID>) -> Void = { _ in }
    /// Every push that ends: how many changes landed and how many didn't
    /// (Settings → Notifications).
    var onFinished: (_ landed: Int, _ failed: Int) -> Void = { _, _ in }

    let queue: ChangeQueue
    let history: PushHistory
    /// Where `{secret:…}` placeholders are read from (the Keychain).
    private let secrets: any SecretStore
    private let now: () -> Date
    private var task: Task<Void, Never>?
    private var isCancelling = false
    /// In-App Texts drafts found or made during this push, by
    /// `InAppDraftWrite.ownerKey`, so every locale's change goes into one.
    private var inAppDrafts: [String: String] = [:]
    /// Owners App Store Connect wouldn't make a draft for in this push, so
    /// their other locales fail with the same reason without asking again.
    private var inAppDraftRefusals: [String: InAppDraftRefusal] = [:]
    /// Custom product pages' versions and new pages' IDs, found or made
    /// earlier in this push.
    let productPages = ProductPagePushState()
    /// How long a new page Apple failed on is looked for, and the pause
    /// before a page write's one automatic retry (tests: `.immediate`).
    var productPagePacing = ProductPagePushPacing.standard
    /// New versions' IDs, localizations and App Review details, for the
    /// texts that wait with them.
    let queuedVersions = QueuedVersionPushState()
    /// Steps side-by-side changes share, one at a time (a group, a draft,
    /// the territories), and requests a change fans out to, a few at once.
    let slots: PushSlots
    /// New subscriptions' groups, App Store Connect's territories and
    /// starting prices, shared by the push's changes.
    let subscriptionSetup: SubscriptionSetupPushState
    /// Each event's languages in App Store Connect by locale, read when an
    /// upload names a language the push created (`EventLocalizationPlaceholder`).
    private var eventLocalizations: [String: [String: String]] = [:]
    /// Wakes the send loop when Apple takes over an upload.
    private(set) var wakeLoop: AsyncStream<PushLoopEvent>.Continuation?
    /// Items uploaded and processing at Apple: they don't hold a place.
    private(set) var waitingOnApple: Set<Int> = []
    /// How far changes that didn't finish got, by change.
    var unfinished: [PendingChange.ID: PushItem] = [:]
    /// Requests this hour, shared with screenshot pushes.
    let rateTracker: RequestRateTracker
    /// Screenshot pushes: images uploaded set by set beside these changes.
    let screenshots: ScreenshotPushController

    init(
        queue: ChangeQueue,
        history: PushHistory,
        transport: (any PushTransport)? = nil,
        secrets: any SecretStore = KeychainSecretStore(),
        now: @escaping () -> Date = { .now }
    ) {
        self.queue = queue
        self.history = history
        self.transport = transport
        self.secrets = secrets
        self.now = now
        let slots = PushSlots()
        self.slots = slots
        subscriptionSetup = SubscriptionSetupPushState(slots: slots)
        let rateTracker = RequestRateTracker(now: now)
        self.rateTracker = rateTracker
        screenshots = ScreenshotPushController(history: history, rate: rateTracker, now: now)
        screenshots.appName = { [weak self] id in self?.appName(id) ?? id }
        screenshots.onPushed = { [weak self] appIDs in self?.onPushed(appIDs) }
    }

    /// Requests used this hour: Apple's own count when a response reported
    /// it, otherwise what this Mac sent in the last hour.
    var rateLimit: AppStoreConnectRateLimit { rateTracker.rateLimit }

    // MARK: - Running

    /// Starts pushing `changes` in order, except that retention offers wait
    /// for their app's retention messages. Blocked ones are left in review.
    func push(_ changes: [PendingChange]) {
        guard phase != .running else { return }
        rememberUnfinished()
        let ordered = InAppEventPushOrder.sorted(RetentionPushOrder.sorted(changes.filter { !$0.isBlocked }))
        items = QueuedVersionPushOrder.sorted(ProductPageScreenshotsPushOrder.sorted(ordered)).map(resumed)
        notice = nil
        inAppDrafts = [:]
        inAppDraftRefusals = [:]
        productPages.reset()
        queuedVersions.reset()
        subscriptionSetup.reset()
        eventLocalizations = [:]
        guard !items.isEmpty else { return }
        run()
    }

    /// Lets the requests in flight finish and marks the rest as not sent.
    func cancelRemaining() {
        guard phase == .running else { return }
        isCancelling = true
    }

    /// Sends the failed changes again, resuming after any request of theirs
    /// that already went through.
    func retryFailed() {
        guard phase == .finished else { return }
        var retried = false
        for index in items.indices where items[index].status.isFailure {
            if let current = queue.change(id: items[index].id) {
                // Edited before the retry: what was sent no longer lines up.
                if !Self.sentTheSameRequests(items[index], as: current) { Self.forgetProgress(of: &items[index]) }
                items[index].change = current
                items[index].status = .queued
                retried = true
            }
        }
        guard retried else { return }
        notice = nil
        inAppDraftRefusals = [:]
        run()
    }

    /// Clears a finished push so the sheet shows the review list again.
    func dismissFinished() {
        guard phase == .finished else { return }
        rememberUnfinished()
        phase = .idle
        items = []
    }

    /// Shows a banner about App Store Connect (offline, rate limited, an
    /// API error) outside a push, e.g. when a section's load hit one.
    func report(_ notice: PushNotice) {
        if notice == .offline, !showsOfflineNotice { return }
        self.notice = notice
    }

    func dismissNotice() {
        notice = nil
    }

    /// Waits for the current push to end (tests).
    func waitUntilFinished() async {
        await task?.value
    }

    private func run() {
        phase = .running
        startedAt = now()
        isCancelling = false
        task = Task { [weak self] in
            await self?.sendQueuedItems()
        }
    }

    private func sendQueuedItems() async {
        var tally = PushTally()
        let waits = PushSchedule.waits(for: items.map(\.change))
        let (events, wake) = AsyncStream.makeStream(of: PushLoopEvent.self)
        var iterator = events.makeAsyncIterator()
        wakeLoop = wake
        waitingOnApple = []
        var running = 0
        while true {
            stopRemaining(tally.stopReason)
            while PushSchedule.hasRoom(running: running, waitingOnApple: waitingOnApple.count), let index = nextReady(waits) {
                let batch = mergedBatch(startingAt: index)
                // Taken now, so the next pick skips them.
                for item in batch { items[item].status = .sending }
                running += 1
                Task { await wake.yield(.finished(self.process(batch: batch))) }
            }
            guard running > 0, let event = await iterator.next(isolation: #isolation) else { break }
            switch event {
            case let .finished(outcomes):
                running -= 1
                for (index, outcome) in outcomes {
                    waitingOnApple.remove(index)
                    tally.add(outcome, for: items[index].id)
                }
            case let .waitingOnApple(index):
                waitingOnApple.insert(index)
            }
        }
        wake.finish()
        wakeLoop = nil
        record(failures: tally.failures)
        phase = .finished
        isCancelling = false
        if failedCount > 0, notice == nil {
            notice = .partialFailure(failed: failedCount, total: totalCount)
        }
        if !tally.pushedApps.isEmpty { onPushed(tally.pushedApps) }
        onFinished(totalCount - failedCount, failedCount)
    }

    /// After a stop (rate limit, offline) or Cancel Remaining: what hasn't
    /// started won't.
    private func stopRemaining(_ stopReason: String?) {
        guard let reason = stopReason ?? (isCancelling ? String(localized: "Cancelled") : nil) else { return }
        for index in items.indices where items[index].status == .queued {
            items[index].status = .notSent(reason)
        }
    }

    /// The first queued item whose earlier changes it depends on are all
    /// finished. Items sent with an earlier one's merged request aren't
    /// queued anymore by then.
    private func nextReady(_ waits: [[Int]]) -> Int? {
        items.indices.first { index in
            items[index].status == .queued && waits[index].allSatisfy { items[$0].status.isFinished }
        }
    }

    /// Sends one item, or several that share a merged request.
    private func process(batch: [Int]) async -> [(Int, PushItemOutcome)] {
        if batch.count > 1 { return await processMerged(batch) }
        return await [(batch[0], process(batch[0]))]
    }

    /// Sends one item and sets its status.
    private func process(_ index: Int) async -> PushItemOutcome {
        guard prepare(index) else { return .skipped }
        let change = items[index].change
        do {
            try await send(index)
            items[index].status = .done
            removePushed(index)
            return .pushed(change.appID)
        } catch let conflict as ConflictFound {
            items[index].status = .conflict
            queue.markRemoteConflict(id: change.id, conflict.conflict)
            return .skipped
        } catch {
            let (handled, stop) = handle(error)
            let status = ProductPageStepFailure.status(handled, stop: stop, error: error, item: items[index])
            items[index].status = status
            return Self.outcome(status, stop: stop)
        }
    }

    // MARK: - Merged writes

    /// The queued items sent with the one at `index`: itself, then the later
    /// ones whose change shares its merge key.
    private func mergedBatch(startingAt index: Int) -> [Int] {
        guard let key = queue.change(id: items[index].id)?.mergeKey else { return [index] }
        return [index] + items.indices.filter { other in
            other > index && items[other].status == .queued && queue.change(id: items[other].id)?.mergeKey == key
        }
    }

    /// Sends items whose changes write one resource App Store Connect only
    /// takes whole: their conflict checks (one `GET` per path), then a
    /// single `PATCH` with all their attributes. Those that go out succeed
    /// or fail together.
    private func processMerged(_ indices: [Int]) async -> [(Int, PushItemOutcome)] {
        var sending = indices.filter { prepare($0) }
        var outcomes = indices.filter { !sending.contains($0) }.map { ($0, PushItemOutcome.skipped) }
        do {
            guard let transport else { throw AppStoreConnectError.invalidResponse }
            let conflicted = try await markMergedConflicts(among: sending, transport: transport)
            outcomes += conflicted.map { ($0, .skipped) }
            sending.removeAll(where: conflicted.contains)
            guard !sending.isEmpty else { return outcomes }
            try await sendMerged(sending, transport: transport)
            outcomes += sending.map { ($0, .pushed(items[$0].change.appID)) }
        } catch {
            let (status, stop) = handle(error)
            for index in sending where items[index].status == .sending {
                items[index].status = status
                outcomes.append((index, Self.outcome(status, stop: stop)))
            }
        }
        return outcomes
    }

    /// Takes the item at `index` from the queue to send it, or sets why it
    /// can't go (discarded, or blocked by a conflict or a problem).
    private func prepare(_ index: Int) -> Bool {
        guard let change = queue.change(id: items[index].id) else {
            items[index].status = .notSent(String(localized: "Discarded"))
            return false
        }
        guard !change.isBlocked else {
            items[index].status = change.needsDecision ? .conflict : .notSent(change.blockingMessage ?? "")
            return false
        }
        items[index].change = change
        items[index].status = .sending
        return true
    }

    /// Runs the merged items' conflict checks, fetching each path once, and
    /// marks those App Store Connect changed since; returns them.
    private func markMergedConflicts(among indices: [Int], transport: any PushTransport) async throws -> [Int] {
        var fetched: [String: Data] = [:]
        var conflicted: [Int] = []
        for index in indices {
            guard let check = items[index].change.conflictCheck else { continue }
            if fetched[check.path] == nil {
                let response = try await transport.fetch(check.path)
                noteRequest(response.rateLimit)
                fetched[check.path] = response.data
            }
            let actual = check.value(in: fetched[check.path] ?? Data())
            guard check.differs(from: actual) else { continue }
            items[index].status = .conflict
            queue.markRemoteConflict(
                id: items[index].id,
                RemoteConflict(remoteRawValue: actual, remoteDisplayValue: check.format.display(actual))
            )
            conflicted.append(index)
        }
        return conflicted
    }

    /// One `PATCH` for every item in `indices`, which are all done after it.
    private func sendMerged(_ indices: [Int], transport: any PushTransport) async throws {
        guard let request = PushRequest.merged(indices.map { items[$0].change.pushRequests[0] }) else {
            throw AppStoreConnectError.invalidResponse
        }
        let resolved = try request.resolved(createdID: nil) { try secrets.secret(named: $0) }
        let response = try await transport.send(resolved)
        noteRequest(response.rateLimit)
        for index in indices {
            items[index].sentRequestCount = 1
            items[index].status = .done
            queue.remove(pushed: items[index].id)
        }
    }

    /// Checks for a conflict, then sends the item's remaining requests.
    private func send(_ index: Int) async throws {
        guard let transport else { throw AppStoreConnectError.invalidResponse }
        let change = items[index].change
        if items[index].sentRequestCount == 0, let check = change.conflictCheck {
            let response = try await transport.fetch(check.path)
            noteRequest(response.rateLimit)
            let actual = check.value(in: response.data)
            if check.differs(from: actual) {
                throw ConflictFound(conflict: RemoteConflict(remoteRawValue: actual, remoteDisplayValue: check.format.display(actual)))
            }
        }
        for request in change.pushRequests.dropFirst(items[index].sentRequestCount) {
            do {
                try await send(request, at: index, transport: transport)
            } catch {
                // Method and path only: bodies can hold texts and secrets.
                Self.logger.error("\(change.id, privacy: .public): \(request.method.rawValue, privacy: .public) \(request.path, privacy: .public) failed: \(String(describing: error), privacy: .public)")
                throw error
            }
            items[index].sentRequestCount += 1
        }
    }

    func noteRequest(_ rateLimit: AppStoreConnectRateLimit?) {
        rateTracker.note(rateLimit)
    }

    /// Changes the row at `index`, for the extensions that send a step.
    func update(_ index: Int, _ change: (inout PushItem) -> Void) {
        change(&items[index])
    }

    /// The row status for an error, and why the rest stop, if they do.
    private func handle(_ error: any Error) -> (PushItemStatus, stop: String?) {
        if let status = Self.waitingStatus(error) { return (status, nil) }
        // A write that timed out or that Apple's server failed on may have
        // been made anyway: never "Not sent", and it says to refresh before
        // a retry makes it twice.
        if let status = Self.timedOutStatus(error) { return (status, nil) }
        if let error = error as? AppStoreConnectError {
            switch error {
            case .rateLimited:
                notice = .rateLimited(resumeAt: rateTracker.nextHour())
                return (.notSent(String(localized: "Rate limited")), String(localized: "Rate limited"))
            case .unauthorized, .invalidPrivateKey:
                notice = .apiError(error.errorDescription ?? "")
                return (.failed(error.pushFailureText), String(localized: "Stopped"))
            default:
                return (.failed(error.pushFailureText), nil)
            }
        }
        if let error = error as? URLError, Self.offlineCodes.contains(error.code) {
            if showsOfflineNotice { notice = .offline }
            return (.notSent(String(localized: "Offline")), String(localized: "Offline"))
        }
        return (.failed(Self.failureText(error)), nil)
    }

    /// One Activity record per app that had something sent or refused.
    private func record(failures: [PendingChange.ID: String]) {
        let attempted = items.filter { $0.status == .done || failures[$0.id] != nil }
        let byApp = Dictionary(grouping: attempted, by: \.change.appID)
        let date = now()
        for (appID, appItems) in byApp {
            let pushed = appItems.filter { $0.status == .done }.map(\.change)
            let failed = appItems.compactMap { item in failures[item.id].map { (item.id, $0) } }
            let record = PushRecord(
                date: date,
                appID: appID,
                appName: appName(appID),
                title: PushRecord.title(for: appItems.map(\.change)),
                pushed: pushed,
                failures: Dictionary(uniqueKeysWithValues: failed),
                failedChanges: appItems.filter { failures[$0.id] != nil }.map(\.change)
            )
            history.add(record)
            // Pricing's history keeps each price change and, later, the
            // 28 days either side for Results and HowSure.
            recordPricing(record)
        }
    }

    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
    ]

    /// Thrown by `send` when the conflict check found a different value.
    private struct ConflictFound: Error {
        var conflict: RemoteConflict
    }
}

// The writes a refused or versioned localization `POST` turns into, and a
// new subscription's steps.
extension PushController {
    fileprivate static let logger = Logger(subsystem: "com.lima.atlas", category: "Push")

    /// One of a change's requests, its placeholders filled in.
    private func send(_ request: PushRequest, at index: Int, transport: any PushTransport) async throws {
        let queued = try await resolvingQueuedVersion(checkingQueuedSubscription(in: request), at: index, transport: transport)
        let request = try await resolvingSetupPlaceholders(resolvingNomination(queued.request, at: index, via: transport), at: index, transport: transport)
        defer { noteReviewDetail(madeBy: queued, at: index) }
        if try await sendSetupStep(request, at: index, transport: transport) { return }
        let resolved = try request.resolved(createdID: items[index].createdID) { try secrets.secret(named: $0) }
        if let create = ProductPageCreate(resolved) {
            try await send(create, at: index, transport: transport)
            return
        }
        do {
            let response = try await transport.send(resolved)
            noteRequest(response.rateLimit)
            if request.method == .post { noteCreated(response.data, at: index) }
        } catch let error as AppStoreConnectError where error.isDuplicate {
            guard let update = ExistingLocalizationUpdate(resolved) else { throw error }
            items[index].createdID = try await updateExisting(update, refusal: error, transport: transport)
        } catch let error as AppStoreConnectError where error.isUnmodifiable {
            // A pre-4.4.1 texts write: the same texts go into a version.
            guard let legacy = LegacyInAppTextWrite(resolved) else { throw error }
            let write = try await legacy.draftWrite(via: transport) { noteRequest($0) }
            items[index].createdID = try await send(write, transport: transport)
        }
    }

    /// The `data` of a `POST`'s response: the resource it created, kept
    /// for `{createdID}` and `{createdID:<type>}`.
    private func noteCreated(_ data: Data, at index: Int) {
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let resource = object?["data"] as? [String: Any]
        guard let id = resource?["id"] as? String else { return }
        items[index].createdID = id
        if let type = resource?["type"] as? String { items[index].createdIDs[type] = id }
    }

    /// The request with its `{subscriptionGroup:…}` (found or created now,
    /// once per push), a new In-App Event's `{everyTerritory}`, an event
    /// language created earlier in the push (`{eventLocalization:…}`), a retention
    /// image and placement group, and `{createdID:<type>}` filled in.
    private func resolvingSetupPlaceholders(_ request: PushRequest, at index: Int, transport: any PushTransport) async throws -> PushRequest {
        // A price test's old prices come back on day 28 from today.
        var request = PriceTestReturnDay.resolving(request)
        if let event = NewInAppEventEverywhere(request) {
            request = try await event.request(territoryIDs: everyTerritory(transport: transport))
        }
        while let group = SubscriptionGroupPlaceholder(in: request) {
            request = try await request.replacing(group.token, with: subscriptionSetup.groupID(group, via: transport) { noteRequest($0) })
        }
        while let language = EventLocalizationPlaceholder(in: request) {
            request = try await request.replacing(language.token, with: eventLocalizationID(language, transport: transport))
        }
        let retention = try await RetentionPushSteps.resolving(request, known: items[index].createdIDs, via: transport) { noteRequest($0) }
        items[index].createdIDs.merge(retention.created) { _, new in new }
        return try retention.request.resolvingCreatedIDs(items[index].createdIDs)
    }

    /// Sends the app's price schedule or first availability; false for any
    /// other request.
    private func sendAppSaleStep(_ request: PushRequest, transport: any PushTransport) async throws -> Bool {
        guard let write = AppPriceAvailabilityWrite(request) else { return false }
        let response = try await write.send(via: transport)
        noteRequest(response.rateLimit)
        return true
    }

    /// Sends a request that's more than one write: a new subscription or
    /// App Store version (found when a push before created it), an In-App Texts write into a
    /// version, an event's card or details page upload, availability
    /// everywhere, or a subscription's starting prices, a retention step,
    /// or the app's price or first availability. False for any other
    /// request.
    private func sendSetupStep(_ request: PushRequest, at index: Int, transport: any PushTransport) async throws -> Bool {
        let retention = try await RetentionPushSteps.sendSetupStep(request, via: transport) { noteRequest($0) } created: { type, id in
            items[index].createdID = id
            items[index].createdIDs[type] = id
        }
        // The app's price or first availability: one POST, its refusal explained.
        let appSale = try await sendAppSaleStep(request, transport: transport)
        if retention || appSale { return true }
        if try await sendPurchaseSetupStep(request, at: index, transport: transport) { return true }
        if let create = NewSubscriptionCreate(request) {
            let id = try await create.send(via: transport) { noteRequest($0) }
            items[index].createdID = id
            items[index].createdIDs["subscriptions"] = id
            return true
        }
        if let create = NewAppStoreVersionCreate(request) {
            let id = try await create.send(via: transport) { noteRequest($0) }
            items[index].createdID = id
            items[index].createdIDs["appStoreVersions"] = id
            return true
        }
        if let write = InAppDraftWrite(request) {
            items[index].createdID = try await send(write, transport: transport)
            return true
        }
        if let write = ProductPageLocaleWrite(request) {
            let sent = try await productPages.send(write, transport: transport, pause: productPagePacing.retryPause) { noteRequest($0) }
            items[index].createdIDs[ProductPageLocaleWrite.versionType] = sent.versionID
            if let localizationID = sent.localizationID { items[index].createdIDs[ProductPageLocaleWrite.localizationType] = localizationID }
            return true
        }
        if try await sendMediaSet(request, at: index, transport: transport) { return true }
        if let artwork = InAppEventArtworkPush(request) {
            defer { items[index].progressNote = nil }
            items[index].createdID = try await artwork.send(
                via: transport,
                note: { noteRequest($0) },
                progress: { items[index].progressNote = $0 },
                processing: { wakeLoop?.yield(.waitingOnApple(index)) },
                pollInterval: { PushSchedule.pollInterval(waitingOnApple: waitingOnApple.count) }
            )
            return true
        }
        guard let prices = SubscriptionStartingPrices(request) else { return false }
        defer { items[index].progressNote = nil }
        try await subscriptionSetup.send(prices, via: transport) { set, total in
            items[index].progressNote = String(localized: "Prices · \(set) of \(total)")
        } note: { rateLimit in
            noteRequest(rateLimit)
        }
        return true
    }

    /// The ID of an event's language, read again when it isn't known yet:
    /// an earlier change of this push may have just created it.
    private func eventLocalizationID(_ language: EventLocalizationPlaceholder, transport: any PushTransport) async throws -> String {
        if let id = eventLocalizations[language.eventID]?[language.locale] { return id }
        let ids = try await EventLocalizationPlaceholder.localizationIDs(eventID: language.eventID, via: transport) { noteRequest($0) }
        eventLocalizations[language.eventID] = ids
        guard let id = ids[language.locale] else { throw EventLocalizationPlaceholder.Missing(locale: language.locale) }
        return id
    }

    /// Every territory App Store Connect has, read on first use in a push.
    func everyTerritory(transport: any PushTransport) async throws -> [String] {
        try await subscriptionSetup.everyTerritory(via: transport) { noteRequest($0) }
    }

    /// An In-App Texts write into the owner's editable version, the one
    /// found or made earlier in this push when there is one. Returns the
    /// localization's ID. Writes going side by side take turns per locale,
    /// and while the owner's draft isn't known the first finds or makes it
    /// and the others wait for it.
    private func send(_ write: InAppDraftWrite, transport: any PushTransport) async throws -> String? {
        try await slots.run("inAppText:\(write.ownerKey):\(write.locale)") {
            if inAppDrafts[write.ownerKey] == nil {
                var sent: String?
                var wrote = false
                try await slots.run("inAppDraft:\(write.ownerKey)") {
                    guard inAppDrafts[write.ownerKey] == nil else { return }
                    sent = try await sendNow(write, transport: transport)
                    wrote = true
                }
                if wrote { return sent }
            }
            return try await sendNow(write, transport: transport)
        }
    }

    private func sendNow(_ write: InAppDraftWrite, transport: any PushTransport) async throws -> String? {
        if let refusal = inAppDraftRefusals[write.ownerKey] { throw refusal }
        let sent: (versionID: String, localizationID: String?, rateLimit: AppStoreConnectRateLimit?)
        do {
            sent = try await write.send(via: transport, knownVersionID: inAppDrafts[write.ownerKey])
        } catch let refusal as InAppDraftRefusal {
            inAppDraftRefusals[write.ownerKey] = refusal
            throw refusal
        }
        inAppDrafts[write.ownerKey] = sent.versionID
        noteRequest(sent.rateLimit)
        return sent.localizationID
    }

    /// A new locale's `POST` refused because the locale is there by now:
    /// the same texts go onto that localization when that overwrites
    /// nothing. Returns its ID; throws `refusal` when it can't be found.
    private func updateExisting(
        _ update: ExistingLocalizationUpdate,
        refusal: AppStoreConnectError,
        transport: any PushTransport
    ) async throws -> String {
        let found = try await transport.fetch(update.lookupPath)
        noteRequest(found.rateLimit)
        guard let existing = update.existing(in: found.data) else { throw refusal }
        guard existing.overwritten.isEmpty else { throw update.otherText(in: existing.overwritten) }
        if let request = update.update(id: existing.id) {
            let response = try await transport.send(request)
            noteRequest(response.rateLimit)
        }
        return existing.id
    }
}
