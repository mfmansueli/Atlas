//
//  OverviewSectionView+Content.swift
//  Atlas
//

import Foundation

extension OverviewSectionView {
    /// Reads the page the preview draws into `kept`, stamped when it
    /// worked, as Overview does when it opens and the read ahead does
    /// before; nil when it failed (a cancelled read leaves `kept` alone).
    static func readContent(
        for app: StoreApp,
        services: any StorePageServices,
        into kept: AppSectionModels?,
        refreshCount: Int
    ) async -> StorePageContent? {
        let loaded = try? await services.content(for: app, versionID: nil)
        guard !Task.isCancelled else { return nil }
        kept?.overviewContent = loaded
        if loaded != nil { kept?.didLoad(.overview, refreshCount: refreshCount) }
        return loaded
    }
}
