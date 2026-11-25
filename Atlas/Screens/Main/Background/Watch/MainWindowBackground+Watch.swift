//
//  MainWindowBackground+Watch.swift
//  Atlas
//

import Foundation

// Look for Improvements, at the end of each check (`WatchCenter`).
extension MainWindowBackground {
    /// Atlas's own checks over what this check read, for every app (free,
    /// always on), then, with the switch on and Pro and within the budget,
    /// at most one Claude Code run for the findings left.
    func lookForImprovements() async {
        let center = watch
        launcher.assistants.onOriginProposal = { origin, tool, lines in
            center.noteProposal(origin: origin, tool: tool, lines: lines)
        }
        let now = center.now()
        let reader = WatchInputsReader(
            analytics: analytics, releases: releases, reviews: reviews, events: .shared, launcher: launcher, services: services,
            keptModels: watchSources.keptModels
        )
        var inputs: [WatchInputs] = []
        for app in library.apps {
            await inputs.append(reader.inputs(for: app, now: now))
        }
        var dedupe: [StoreApp.ID: WatchDedupe] = [:]
        for input in inputs {
            dedupe[input.appID] = WatchDedupe.make(
                for: WatchDetectors.signals(in: input), appID: input.appID, suggestions: watchSources.suggestions,
                findings: analytics.findings(for: input.appID), now: now
            )
        }
        await center.check(inputs, context: watchContext(), dedupe: dedupe, suggestions: watchSources.suggestions, launcher: launcher)
    }

    /// The switch, Pro, Claude Code and the apps' folders, the runs going
    /// and the quota, as they are now.
    private func watchContext() async -> WatchContext {
        let isOn = watchSources.isOn()
        let isPro = watchSources.isPro()
        // Asked right after Atlas opens, before anything started Claude Code.
        if isOn, isPro, launcher.helper == .unknown { await launcher.refreshHelper() }
        return WatchContext(
            isOn: isOn,
            isPro: isPro,
            canStartClaudeCode: launcher.canStart,
            appsWithProjectFolder: Set(library.apps.map(\.id).filter { launcher.projectFolder(for: $0) != nil }),
            activeRunCount: launcher.activeRuns.count,
            quota: watchSources.quota()
        )
    }
}
