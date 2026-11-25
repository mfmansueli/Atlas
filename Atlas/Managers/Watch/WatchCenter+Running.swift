//
//  WatchCenter+Running.swift
//  Atlas
//

import Foundation

// One check: the findings, the ledger's decisions, the budget, and the run
// for each app that's left something to send.
extension WatchCenter {
    /// Everything a check does, at the end of the hourly check: the runs
    /// that ended are noted, the findings observed and decided, the outcomes
    /// of earlier runs settled, and at most one run started (never asking
    /// for a project folder). Returns what it found and decided.
    @discardableResult
    func check(
        _ inputs: [WatchInputs], context: WatchContext, dedupe: [StoreApp.ID: WatchDedupe] = [:], suggestions: FieldSuggestionStore?,
        launcher: ClaudeCodeLauncher?
    ) async -> WatchPlan {
        for app in inputs {
            _ = archive(for: app.appID)
        }
        if let launcher { noteEndedRuns(in: launcher) }
        var context = context
        context.usageLimitHitAt = [context.usageLimitHitAt, usageLimitHitAt(launcher: launcher)].compactMap(\.self).max()
        let plan = plan(inputs, context: context, dedupe: dedupe)
        settle(Dictionary(uniqueKeysWithValues: plan.apps.map { ($0.appID, $0.signals) }), suggestions: suggestions)
        if let launcher { await start(plan, launcher: launcher) }
        setLastPlan(plan)
        return plan
    }

    /// The findings of each app, observed in its record, and what the
    /// ledger and the budget make of them. A planned run counts toward the
    /// day's caps and as a run going for the apps after it, so a check
    /// starts one run at most.
    func plan(_ inputs: [WatchInputs], context: WatchContext, dedupe: [StoreApp.ID: WatchDedupe] = [:]) -> WatchPlan {
        let date = now()
        var context = context
        var runStarts = runStarts
        var plan = WatchPlan(date: date)
        for app in inputs {
            let signals = WatchDetectors.signals(in: app)
            update(app.appID) { WatchLedger.observe(signals, in: &$0, now: date) }
            let decisions = WatchLedger.decide(signals, in: archive(for: app.appID), dedupe: dedupe[app.appID] ?? WatchDedupe(), now: date)
            var item = WatchPlan.App(appID: app.appID, appName: app.appName, decisions: decisions)
            if !item.toSend.isEmpty {
                if let refusal = budget.refusal(for: app.appID, context: context, runStarts: runStarts, now: date) {
                    item.refusal = refusal
                } else {
                    item.prompt = WatchPrompt.text(appID: app.appID, appName: app.appName, signals: item.toSend)
                    runStarts.append((app.appID, date))
                    context.activeRunCount += 1
                }
            }
            plan.apps.append(item)
        }
        return plan
    }

    /// Starts the plan's runs, in the project folder Atlas knows (never
    /// asking for one), and keeps each in the History.
    func start(_ plan: WatchPlan, launcher: ClaudeCodeLauncher) async {
        for app in plan.apps {
            guard let prompt = app.prompt, launcher.projectFolder(for: app.appID) != nil,
                  let runID = await launcher.start(.watch, appID: app.appID, appName: app.appName, prompt: prompt)
            else { continue }
            let date = now()
            update(app.appID) { archive in
                WatchLedger.markSent(app.toSend, runID: runID, in: &archive, now: date)
                archive.append(WatchHistoryEntry(id: runID, appID: app.appID, appName: app.appName, startedAt: date, signals: app.toSend))
            }
        }
    }

    /// The History's runs that ended since, as the launcher tells it; one
    /// the launcher no longer has ended with Atlas.
    func noteEndedRuns(in launcher: ClaudeCodeLauncher) {
        let working = archives.flatMap { appID, archive in archive.history.filter(\.result.isWorking).map { (appID, $0.id) } }
        for (appID, runID) in working {
            let run = launcher.run(runID)
            if run?.isActive == true { continue }
            let result = run.map(Self.result) ?? .interrupted
            let endedAt = run?.endedAt ?? now()
            update(appID) { archive in
                archive.updateEntry(runID) { entry in
                    entry.result = result
                    entry.endedAt = endedAt
                }
            }
        }
    }

    /// When Claude Code last stopped on the usage limit: in the launcher's
    /// recent runs, or in the History.
    func usageLimitHitAt(launcher: ClaudeCodeLauncher?) -> Date? {
        let fromRuns = (launcher?.runs ?? []).filter { Self.result(of: $0) == .usageLimit }.map { $0.endedAt ?? $0.startedAt }
        let fromHistory = archives.values.flatMap(\.history).filter { $0.result == .usageLimit }.compactMap(\.endedAt)
        return (fromRuns + fromHistory).max()
    }

    static func result(of run: ClaudeCodeRun) -> WatchRunResult {
        switch run.phase {
        case .starting, .working: .working
        case .finished: .finished
        case .stopped: .stopped
        case let .failed(failure): isUsageLimit(failure, at: run.endedAt ?? run.startedAt) ? .usageLimit : .failed(reason: failure.title)
        }
    }

    private static func isUsageLimit(_ failure: ClaudeCodeRunFailure, at date: Date) -> Bool {
        guard case let .claudeError(message) = failure else { return false }
        return ClaudeCodeUsageLimit(message: message, now: date) != nil
    }
}
