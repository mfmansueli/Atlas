//
//  SectionPrefetcher.swift
//  Atlas
//

import Foundation

/// Reads the open app's other sections in the background, so opening one
/// shows its content at once instead of a skeleton. It waits a moment
/// first (the section on screen reads first, and flicking through apps
/// reads nothing), then reads one section at a time in the sidebar's
/// order, skipping the one on screen and the ones whose kept model is
/// still fresh. It stops when the app changes and while App Store
/// Connect's hourly quota is down to its last quarter, which stays for
/// the person's own work.
@MainActor
struct SectionPrefetcher {
    /// How long the open app shows before its other sections are read.
    static let settleDelay: Duration = .seconds(2)

    /// The order sections are read in: the sidebar's.
    static let order = AppWorkspaceSection.allCases

    let models: WorkspaceSectionModels
    var settleDelay: Duration = Self.settleDelay
    var sleep: @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }

    /// Reads `app`'s sections ahead with `warmer`. `shown` is the section
    /// on screen, asked before each read; `quota` the hourly quota last
    /// reported, nil when unknown.
    func prefetch(
        _ app: StoreApp,
        refreshCount: Int,
        using warmer: any SectionWarming,
        shown: () -> AppWorkspaceSection,
        quota: () -> AppStoreConnectRateLimit?
    ) async {
        do { try await sleep(settleDelay) } catch { return }
        for section in Self.order {
            guard !Task.isCancelled else { return }
            if let quota = quota(), !quota.leavesRoomToReadAhead { return }
            guard section != shown() else { continue }
            let kept = models.models(for: app.id)
            guard !kept.isWarming(section), warmer.needsWarming(section, of: app, kept: kept, refreshCount: refreshCount) else { continue }
            await kept.warm(section) {
                await warmer.warm(section, of: app, kept: kept, refreshCount: refreshCount)
            }
        }
    }
}
