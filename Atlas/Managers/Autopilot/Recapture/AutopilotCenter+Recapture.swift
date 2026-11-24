//
//  AutopilotCenter+Recapture.swift
//  Atlas
//

import Foundation

/// A capture-only run (`AutopilotRecapture`): the app's finished run opened
/// again for some of its captures and App Preview moments, by the person
/// (Capture Again with Claude Code) or by accepting the assistant's
/// request. The assistant reads it with get_capture_plan and next_step as
/// any run; the new captures then take the old ones' places in the set,
/// the App Preview is made again when moments were recorded again, and the
/// run is back in Review & Push.
extension AutopilotCenter {
    // MARK: - Opening

    /// Why `appID` can't redo captures now; nil when it can. With no saved
    /// run (or only a new plan that was never started) it can: the plan
    /// comes from the set's captures (`redoesFromCaptures`).
    func recaptureRefusal(appID: StoreApp.ID) -> String? {
        guard let run = runs[appID] else { return nil }
        switch run.stage {
        case .ready:
            return nil
        case .plan where run.startedAt == nil:
            // An open plan Cancel would close gives the run back, or
            // there's no run behind it and the captures make one.
            return nil
        default:
            return String(localized: "Autopilot is at \(run.stage.title) now. Redo captures once its run is in Review & Push, or cancel it.")
        }
    }

    /// The app has no saved run to open again (none at all, or a new plan
    /// never started with nothing behind it): a capture-only run is made
    /// from the set's captures (`AutopilotRecapturePlanFromCaptures`).
    func redoesFromCaptures(appID: StoreApp.ID) -> Bool {
        guard let run = runs[appID] else { return true }
        return run.stage == .plan && run.startedAt == nil && replacedRun(for: appID) == nil
    }

    /// "Alba has no captures to redo yet…": no saved run and nothing in
    /// the set to make one from.
    static func noCapturesRefusal(appName: String) -> String {
        String(localized: """
        \(appName) has no captures yet. Import them in Atlas → Screenshots → Captures, or use Run Autopilot….
        """)
    }

    /// Opens the app's last run again to redo `targets` and record
    /// `momentIDs` again: the plan, template, captions and look stay, the
    /// other captures are reused, and the run waits for the assistant.
    /// With no saved run, `fromCaptures` makes one from the set's captures
    /// first (a new plan never started is closed).
    @discardableResult
    func openRecapture(
        appID: StoreApp.ID, targets: [AutopilotCaptureTarget], momentIDs: [String] = [], reason: String? = nil, evidence: String? = nil,
        client: String? = nil, requestID: String? = nil, fromCaptures: AutopilotRecapturePlanFromCaptures? = nil
    ) throws -> AutopilotRun {
        if let refusal = recaptureRefusal(appID: appID) { throw AutopilotError(refusal) }
        let madeFromCaptures = redoesFromCaptures(appID: appID)
        let base: AutopilotRun
        if madeFromCaptures {
            guard let fromCaptures else {
                throw AutopilotError(String(localized: "No captures to redo yet. Capture the set with Run Autopilot… first."))
            }
            base = fromCaptures.run(id: makeID(), appID: appID, uploadToken: Self.makeToken(), now: now())
        } else {
            guard let saved = runs[appID]?.stage == .plan ? replacedRun(for: appID) : runs[appID], saved.stage == .ready else {
                throw AutopilotError(String(localized: "No Autopilot run yet. Only a run can redo its own captures."))
            }
            base = saved
        }
        try Self.check(targets: targets, momentIDs: momentIDs, in: base)
        if runs[appID]?.stage == .plan { cancelPlan(for: appID) }
        if madeFromCaptures { install(base) }
        guard let run = runs[appID], run.stage == .ready else {
            throw AutopilotError(String(localized: "No Autopilot run yet. Only a run can redo its own captures."))
        }
        let ordered = run.plan.targets.filter(Set(targets).contains)
        var recapture = AutopilotRecapture(
            targets: ordered, momentIDs: momentIDs, reason: Self.trimmed(reason), evidence: Self.trimmed(evidence), client: client,
            requestID: requestID, openedAt: now(), previousFinishedAt: run.finishedAt, previousReview: run.guidedReview,
            previousCaptures: run.captures.filter { ordered.contains($0.target) }, previousRetakes: run.retakes
        )
        recapture.madeFromCaptures = madeFromCaptures ? true : nil
        update(appID) { run in
            run.recapture = recapture
            run.guidedReview = nil
            run.finishedAt = nil
            run.extrasProgress = nil
            run.variantRequest = nil
            run.problems.removeAll(where: \.isOpen)
            for id in momentIDs { run.askToRecordAgain(id) }
            run.stage = .waiting
            run.uploadToken = Self.makeToken()
            run.handedBackAt = now()
            let who = client.map { String(localized: "\($0) asked to redo \(recapture.title)") }
                ?? String(localized: "Redoing \(recapture.title)")
            let line = recapture.reason.map { String(localized: "\(who): \($0)", comment: "kind:other") } ?? who
            run.appendLog(line, kind: .command, at: now())
        }
        return runs[appID] ?? run
    }

    /// What a capture-only run of `run` can redo: the plan's targets and
    /// the App Preview's moments, at least one of them.
    private static func check(targets: [AutopilotCaptureTarget], momentIDs: [String], in run: AutopilotRun) throws {
        let planned = Set(run.plan.targets)
        let unknown = targets.filter { !planned.contains($0) }
        guard unknown.isEmpty else {
            let names = unknown.prefix(3).map { "\(run.plan.screen(id: $0.screenID)?.name ?? $0.screenID) (\($0.locale))" }
            throw AutopilotError(String(localized: "The run’s plan doesn’t capture \(names.formatted(.list(type: .and)))."))
        }
        let moments = Set(run.pickableMoments.map(\.screenID))
        guard momentIDs.allSatisfy(moments.contains) else {
            throw AutopilotError(String(localized: "The App Preview has no such moment: record again one of its moments."))
        }
        guard !targets.isEmpty || !momentIDs.isEmpty else {
            throw AutopilotError(String(localized: "Choose at least one capture or App Preview moment to redo."))
        }
    }

    /// Cancel Run in a capture-only run: what came since it opened goes,
    /// and the run is back in Review & Push as it was.
    func cancelRecapture(appID: StoreApp.ID) {
        guard let run = runs[appID], let recapture = run.recapture, recapture.placedAt == nil else { return }
        making.removeValue(forKey: appID)?.stop()
        // Made from the set's captures: the app had no run, and has none again.
        if recapture.madeFromCaptures == true {
            removeRun(for: appID)
            return
        }
        update(appID) { run in
            let since = recapture.openedAt
            let previous = Set(recapture.previousCaptures.map(\.id))
            run.captures.removeAll { recapture.covers($0.target) && !previous.contains($0.id) }
            let kept = Set(run.captures.map(\.id))
            run.captures += recapture.previousCaptures.filter { !kept.contains($0.id) }
            run.problems.removeAll { $0.reportedAt >= since }
            run.retakes = recapture.previousRetakes
            run.momentRetakes = nil
            run.guidedReview = recapture.previousReview
            run.finishedAt = recapture.previousFinishedAt
            run.extrasProgress = nil
            run.recapture = nil
            run.stage = .ready
            run.appendLog(String(localized: "Stopped redoing \(recapture.title); the set stays as it was"), kind: .event, at: now())
        }
    }

    // MARK: - Moving on

    /// Every capture redone (and every moment recorded again): Pick shows
    /// the new ones, or they go straight into the set.
    func advanceRecapture(_ appID: StoreApp.ID, context: AutopilotContext) async {
        guard !holdsStages, let run = runs[appID], run.isRecapturing, run.stage == .capture, run.isCaptureComplete else { return }
        update(appID) { run in
            if !run.capturingTargets.isEmpty {
                run.appendLog(String(localized: "Redid \(run.capturedCount) of \(run.totalCaptures) captures"), kind: .event, at: now())
            }
            run.stage = run.picksRecaptures && !run.recapturePickTargets.isEmpty ? .pick : .localize
        }
        if runs[appID]?.stage == .localize { await placeRecaptures(appID, context: context) }
    }

    /// Pick in a capture-only run: the capture a redone screen uses, a new
    /// one or the one it had.
    func pickRecapture(_ captureID: String, for target: AutopilotCaptureTarget, appID: StoreApp.ID) {
        update(appID) { run in
            guard run.stage == .pick, run.isRecapturing, run.recapture?.covers(target) == true else { return }
            let candidates = run.captures(for: target) + [run.previousCapture(for: target)].compactMap(\.self)
            guard candidates.contains(where: { $0.id == captureID }) else { return }
            run.recapture?.picks[target.key] = captureID
        }
    }

    /// Use These Captures: the picked ones go into the set.
    func useRecapturePicks(appID: StoreApp.ID, context: AutopilotContext) async {
        guard let run = runs[appID], run.stage == .pick, run.isRecapturing else { return }
        update(appID) { run in
            run.stage = .localize
            run.handedBackAt = now()
        }
        await placeRecaptures(appID, context: context)
    }

    /// The redone captures take their screens' places in the set: the
    /// template and captions stay, so only those images change in Review &
    /// Push. Then the App Preview is made again with the moments recorded
    /// again, and the run is ready.
    func placeRecaptures(_ appID: StoreApp.ID, context: AutopilotContext) async {
        guard !holdsStages, let run = runs[appID], run.stage == .localize, let recapture = run.recapture, recapture.placedAt == nil else { return }
        await whileLocalizing(appID) {
            do {
                var document = try await context.services.loadDocument(for: context.app, primaryLocale: context.primaryLocale)
                for target in recapture.targets {
                    if let placed = AutopilotLocalizer.placed(target, of: run) { document.captures.add(placed) }
                }
                try await context.services.saveDocument(document, for: context.app)
            } catch {
                update(appID) { run in
                    run.appendLog(String(localized: "Couldn’t save the new captures: \(error.localizedDescription)"), kind: .problem, at: now())
                    run.stage = run.picksRecaptures ? .pick : .localize
                }
                return
            }
            update(appID) { run in
                // The old captures of the redone screens go, but the ones kept.
                let chosen = recapture.targets.compactMap { run.finalCapture(for: $0) }
                let used = Set(chosen.map(\.id))
                let previous = Set(recapture.previousCaptures.map(\.id))
                run.captures.removeAll { previous.contains($0.id) && !used.contains($0.id) }
                // An old capture kept at Pick that a new attempt had replaced.
                let present = Set(run.captures.map(\.id))
                run.captures += chosen.filter { !present.contains($0.id) }
                run.recapture?.placedAt = now()
            }
            guard !recapture.momentIDs.isEmpty, let current = runs[appID], Self.makesExtras(current), !current.plan.previewDisplays.isEmpty else {
                finishRecapture(appID)
                return
            }
            _ = await makeExtras(appID, context: context)
            finishRecapture(appID)
        }
    }

    /// Back in Review & Push.
    private func finishRecapture(_ appID: StoreApp.ID) {
        update(appID) { run in
            guard run.stage == .localize, let recapture = run.recapture else { return }
            run.stage = .ready
            run.finishedAt = now()
            run.appendLog(String(localized: "Redid \(recapture.title) · only changed images wait in Review & Push"), kind: .event, at: now())
        }
    }

    private static func trimmed(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }
}
