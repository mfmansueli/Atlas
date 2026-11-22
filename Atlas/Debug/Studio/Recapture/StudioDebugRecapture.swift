//
//  StudioDebugRecapture.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Redoing only some captures, on Lumen's finished run:
/// - `ap-recapture-request`: Screenshots with Claude Code's request to redo
///   a language's captures waiting for Accept or Decline.
/// - `ap-recapture-run`: the capture-only run in Making it, half of the
///   captures redone.
/// - `ap-recapture-pick`: its Pick, each redone capture beside the one
///   before.
/// - `ap-captures-stale`: Screenshots → Captures with that language's
///   captures marked out of date and two of them selected.
/// - `ap-recapture-no-run`: Claude Code's request with no saved Autopilot
///   run (Alba's case): the capture-only run Accept opens is made from the
///   set's captures (`AutopilotRecapturePlanFromCaptures`).
@MainActor
enum StudioDebugRecapture {
    nonisolated static let noRunID = "ap-recapture-no-run"
    nonisolated static let ids = ["ap-recapture-request", "ap-recapture-run", "ap-recapture-pick", "ap-captures-stale", noRunID]

    nonisolated static let requestID = "rr-debug01"
    static let reason = "the phrases were rewritten"
    static let evidence = "Localizable.xcstrings, commit d038b58"
    /// A request's reason as long as real ones get, so the banner wraps it
    /// and keeps its buttons whole.
    static let requestReason = """
    the phrases were rewritten for people looking for affirmations and confidence: Today should show a Confidence \
    phrase, Topics with Confidence selected, then Streak
    """

    static func scene(for id: String) -> StudioDebugExtras.Scene? {
        switch id {
        case "ap-recapture-request":
            let run = StudioDebugGuided.ready(approved: [], pushed: true)
            let targets = targets(in: run)
            let appID = run.appID
            return StudioDebugExtras.Scene(run: run, sheet: false, setUp: { model in
                model.studio.autopilot?.queueRecapture(AutopilotRecaptureRequest(
                    id: requestID, client: StudioDebugRuns.client, receivedAt: StudioDebugRuns.date(day: 21, month: 11, hour: 10),
                    targets: targets, reason: requestReason, evidence: evidence
                ), appID: appID)
            })
        case "ap-recapture-run":
            return StudioDebugExtras.Scene(run: recapturing(arrived: 0.5, stage: .capture), sheet: true)
        case "ap-recapture-pick":
            return StudioDebugExtras.Scene(run: recapturing(arrived: 1, stage: .pick), sheet: true)
        case "ap-captures-stale":
            let run = StudioDebugGuided.ready(approved: [], pushed: true)
            let locale = locale(in: run)
            let staleness = CaptureStaleness(
                reason: reason, evidence: evidence, client: StudioDebugRuns.client, markedAt: StudioDebugRuns.date(day: 21, month: 11, hour: 10)
            )
            return StudioDebugExtras.Scene(run: run, sheet: false, setUp: { model in
                model.tab = .captures
                model.captures.selection = [
                    CaptureCellKey(locale: locale, displayType: .iPhone, slot: 0), CaptureCellKey(locale: locale, displayType: .iPhone, slot: 1),
                ]
            }, documentChange: { document in
                for slot in 0..<document.slotCount {
                    document.captures.markStale(locale: locale, displayType: .iPhone, slot: slot, as: staleness)
                }
            })
        default:
            return nil
        }
    }

    /// `ap-recapture-no-run`'s request: the second language's captures, as
    /// request_recapture asks for them when the app has no saved run.
    static func queueRequestFromCaptures(on model: ScreenshotsViewModel) {
        guard let center = model.studio.autopilot, let fromCaptures = model.studio.recapturePlanFromCaptures else { return }
        let locales = fromCaptures.plan.capturedLocales
        let locale = locales.dropFirst().first ?? locales.first ?? "ja"
        let targets = fromCaptures.captures.map(\.target).filter { $0.locale == locale }
        center.queueRecapture(AutopilotRecaptureRequest(
            id: requestID, client: StudioDebugRuns.client, receivedAt: StudioDebugRuns.date(day: 21, month: 11, hour: 10),
            targets: targets, reason: reason, evidence: evidence, fromCaptures: fromCaptures
        ), appID: model.studio.app.id)
    }

    /// The language redone: the first after the primary.
    static func locale(in run: AutopilotRun) -> String {
        let locales = run.plan.capturedLocales
        return locales.dropFirst().first ?? locales.first ?? "ja"
    }

    static func targets(in run: AutopilotRun) -> [AutopilotCaptureTarget] {
        let locale = locale(in: run)
        return run.plan.targets.filter { $0.locale == locale }
    }

    /// The finished run opened again for a language's captures, with
    /// `arrived` of them redone.
    static func recapturing(arrived: Double, stage: AutopilotStage) -> AutopilotRun {
        var run = StudioDebugGuided.ready(approved: [], pushed: true)
        let targets = targets(in: run)
        let opened = StudioDebugRuns.date(day: 21, month: 11, hour: 10, minute: 2)
        run.recapture = AutopilotRecapture(
            targets: targets, reason: reason, evidence: evidence, client: StudioDebugRuns.client, requestID: requestID, openedAt: opened,
            previousFinishedAt: run.finishedAt, previousReview: run.guidedReview,
            previousCaptures: run.captures.filter { targets.contains($0.target) }
        )
        run.guidedReview = nil
        run.finishedAt = nil
        run.stage = stage
        let count = Int((Double(targets.count) * arrived).rounded())
        for (index, target) in targets.prefix(count).enumerated() {
            guard var capture = run.previousCapture(for: target) else { continue }
            capture.id = "redo-\(index)"
            capture.attempt = 1
            capture.receivedAt = opened.addingTimeInterval(Double(index + 1) * 40)
            run.captures.append(capture)
        }
        return run
    }
}
#endif
