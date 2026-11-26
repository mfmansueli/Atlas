//
//  RefreshWindowReader.swift
//  Atlas
//

import Foundation

/// One Refresh's reads (README-DS §15): the app list, the version and its
/// builds, and the open section, side by side, each telling the navigator
/// when it's done and what went wrong. The other sections read when
/// they're next opened.
@MainActor
enum RefreshWindowReader {
    static func read(
        _ count: Int,
        navigator: WorkspaceNavigator,
        release: ReleaseViewModel?,
        appID: StoreApp.ID?,
        models: WorkspaceSectionModels,
        loadApps: @escaping @MainActor (_ report: (RefreshProblem?) -> Void) async -> Void
    ) {
        Task {
            await loadApps { navigator.finishRefresh(.apps, problem: $0, refreshCount: count) }
        }
        Task {
            await release?.load()
            navigator.finishRefresh(.release, problem: release?.loadError.flatMap(RefreshProblem.make(for:)), refreshCount: count)
        }
        Task {
            let message = await RefreshSectionWatch.wait(for: navigator.section, of: appID, in: models, refreshCount: count)
            navigator.finishRefresh(.section, problem: message.map(RefreshProblem.failed(text:)), refreshCount: count)
        }
    }
}
