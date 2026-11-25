//
//  AutopilotBarCenter.swift
//  Atlas
//

import Foundation
import Observation

/// What the Autopilot bar keeps for each app besides the chat and the
/// runs (board 80): the request the person sent from one of its actions
/// (their bubble, and the quote under the working strip), the request
/// that just finished (the strip's “Done” with Show), what finished today
/// (Earlier today in the open bar), and the strips the person closed with
/// ✕. Nothing here reaches Apple: it says where suggestions wait.
@MainActor
@Observable
final class AutopilotBarCenter {
    static let shared = AutopilotBarCenter()

    private(set) var sent: [StoreApp.ID: AutopilotBarRequest] = [:]
    private(set) var done: [StoreApp.ID: AutopilotBarFinished] = [:]
    private(set) var finished: [StoreApp.ID: [AutopilotBarFinished]] = [:]
    /// A request whose run stopped with a problem, for Try Again.
    private(set) var failed: [StoreApp.ID: AutopilotBarRequest] = [:]
    private(set) var dismissed: [StoreApp.ID: Set<String>] = [:]

    @ObservationIgnored var now: () -> Date = Date.init
    @ObservationIgnored var calendar = Calendar.current

    /// The most Earlier today keeps.
    static let earlierLimit = 6

    /// The person clicked one of the bar's actions.
    func send(_ request: AutopilotBarRequest) {
        sent[request.appID] = request
        failed[request.appID] = nil
        done[request.appID] = nil
    }

    /// A request that started nothing after all (the action opened a
    /// section's own flow, or the prompt was copied): no bubble stays.
    func withdraw(appID: StoreApp.ID) {
        sent[appID] = nil
    }

    /// A request's run ended. `subject` is what the assistant worked on
    /// (“Store Page · German”); `text` where its suggestions wait;
    /// `result` what it made (“6 suggestions”). A failed one keeps its
    /// request for Try Again; the others show Done and go under Earlier
    /// today. `section` is where Show goes when the bar didn't send it.
    func finish(
        appID: StoreApp.ID, subject: String, text: String, result: String? = nil, failed isFailure: Bool = false,
        section: AppWorkspaceSection
    ) {
        let request = sent.removeValue(forKey: appID)
        if isFailure {
            if let request { failed[appID] = request }
            return
        }
        let item = AutopilotBarFinished(
            appID: appID, what: request?.text(subject: subject) ?? subject, result: result, text: text,
            section: request?.section ?? section, endedAt: now()
        )
        done[appID] = item
        var list = finished[appID] ?? []
        list.insert(item, at: 0)
        finished[appID] = Array(list.prefix(Self.earlierLimit))
    }

    /// The person closed a strip with ✕, or acted on it.
    func dismiss(_ key: String, appID: StoreApp.ID) {
        dismissed[appID, default: []].insert(key)
        if done[appID]?.key == key { done[appID] = nil }
    }

    /// The bar opened: what finished is under Earlier today now, not on the
    /// strip.
    func opened(appID: StoreApp.ID) {
        done[appID] = nil
    }

    /// Try Again ran the request again, or the person let it go.
    func forgetFailure(appID: StoreApp.ID) {
        failed[appID] = nil
    }

    /// What finished today, newest first.
    func earlierToday(for appID: StoreApp.ID) -> [AutopilotBarFinished] {
        let today = now()
        return (finished[appID] ?? []).filter { calendar.isDate($0.endedAt, inSameDayAs: today) }
    }

    func dismissedKeys(for appID: StoreApp.ID) -> Set<String> {
        dismissed[appID] ?? []
    }

    #if DEBUG
    /// A DEBUG scene's state, as it would be after the person sent and
    /// something finished.
    func debugSet(
        appID: StoreApp.ID, sent: AutopilotBarRequest? = nil, done: AutopilotBarFinished? = nil, finished: [AutopilotBarFinished] = []
    ) {
        self.sent[appID] = sent
        self.done[appID] = done
        self.finished[appID] = finished
        dismissed[appID] = nil
        failed[appID] = nil
    }
    #endif
}
