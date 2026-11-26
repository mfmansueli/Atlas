//
//  RefreshSectionWatch.swift
//  Atlas
//

import Foundation

/// Waits for the open section to finish the read a Refresh asked for. The
/// section reads by itself when `refreshCount` changes and stamps its kept
/// model when the read ends (`AppSectionModels`), so the window looks at
/// that model a few times a second rather than every section reporting
/// back. A section that never says is given up on after `timeout`: the
/// arrow stops, and the section shows what it has.
@MainActor
enum RefreshSectionWatch {
    static let interval: Duration = .milliseconds(250)
    static let timeout: Duration = .seconds(20)

    /// The section's error once its read ended with one; nil when it ended
    /// well, was given up on or there's no app.
    static func wait(
        for section: AppWorkspaceSection,
        of appID: StoreApp.ID?,
        in models: WorkspaceSectionModels,
        refreshCount: Int
    ) async -> String? {
        guard let appID else { return nil }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            // The section's own read starts on the same change: a moment
            // first, so a model's old error isn't read as this one's.
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled, let kept = models.keptModels(for: appID) else { return nil }
            switch kept.refreshProgress(of: section, refreshCount: refreshCount) {
            case .reading: continue
            case .done: return nil
            case let .failed(message): return message
            }
        }
        return nil
    }
}
