//
//  WorkspaceSectionModels+FreshProductPages.swift
//  Atlas
//

import Foundation

extension WorkspaceSectionModels {
    /// The pages the Product Pages section read for an app, while that read
    /// is fresh: no Refresh or push since, and not older than
    /// `maximumAge`. Nil when the section never read them, or must again.
    /// Asking doesn't count as opening the app.
    func freshProductPages(_ appID: StoreApp.ID, refreshCount: Int) -> ProductPagesSnapshot? {
        guard let kept = keptModels(for: appID), !kept.needsLoad(.productPages, refreshCount: refreshCount) else { return nil }
        return kept.productPages?.snapshot
    }
}
