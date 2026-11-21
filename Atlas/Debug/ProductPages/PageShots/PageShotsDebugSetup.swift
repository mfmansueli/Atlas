//
//  PageShotsDebugSetup.swift
//  Atlas
//

#if DEBUG
import Foundation

/// What a board 52 DEBUG scene's page screenshot flow starts with: Private
/// diary's run at a stage, Claude Code standing in (never started), and
/// the set laid out for Making (two made), Result, or put in Review & Push.
struct PageShotsDebugSetup {
    @MainActor static var pending: PageShotsDebugSetup?

    enum Looks {
        /// Claude Code has drawn one of three.
        case drawing
        /// Three drawn, the second chosen, and the lock captured again.
        case chosen
    }

    var stage: PageShotsStage
    var looks: Looks?
    /// Making stops after this many, so the scene shows it under way.
    var madeWhileMaking = 2

    @MainActor
    func apply(to flow: PageShotsFlow) {
        Self.pending = nil
        flow.launch = { _, _ in UUID() }
        flow.stopClaude = { _ in }
        flow.copy = { _ in }
        let studio = flow.studio
        let key = flow.key
        studio.begin(PageShotsDebugData.run(for: flow, stage: stage))
        let stage = stage
        let looks = looks
        let made = madeWhileMaking
        Task { @MainActor in
            await flow.loadSource()
            studio.update(key) { run in
                run.templateName = flow.source?.template?.name ?? ""
                run.displays = flow.source?.displays ?? [.iPhone]
            }
            if let looks { PageShotsDebugData.apply(looks, to: flow) }
            switch stage {
            case .making:
                studio.holdAfter = made
                flow.startAutopilot()
            case .result, .used:
                flow.startAutopilot()
                await studio.waitUntilMade(key)
                if stage == .used { flow.use() }
            default:
                break
            }
        }
    }
}
#endif
