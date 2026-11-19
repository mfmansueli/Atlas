//
//  DebugProductPagesServices.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Lumen Journal's product pages for DEBUG scenes; other apps have none.
@MainActor
struct DebugProductPagesServices: ProductPagesServices {
    var error: AppStoreConnectError?
    var isEmpty = false
    /// 70 pages: the most Apple allows.
    var isAtLimit = false
    /// No version approved yet: keywords can't be chosen.
    var hasNoApprovedVersion = false
    /// Never answers, for the loading scene.
    var neverLoads = false

    func pages(for app: StoreApp) async throws -> ProductPagesSnapshot {
        if neverLoads { try await Task.sleep(for: .seconds(3600)) }
        if let error { throw error }
        guard app.id == DebugProductPagesData.appID else {
            return ProductPagesSnapshot(pages: [], defaultPage: ProductPageDefault(), readAt: DebugProductPagesData.now)
        }
        var snapshot = DebugProductPagesData.snapshot
        if isEmpty { snapshot.pages = [] }
        if isAtLimit {
            let filler = (snapshot.pages.count..<(ProductPagesSnapshot.limit - 1)).map { index in
                ProductPage(
                    id: "filler-\(index)", name: "Campaign \(index + 1)", url: DebugProductPagesData.link("filler-\(index)"), isVisible: false,
                    versions: [ProductPageVersion(id: "filler-v-\(index)", number: 1, state: .approved)]
                )
            }
            snapshot.pages += filler
        }
        if hasNoApprovedVersion {
            snapshot.defaultPage.approvedVersionString = nil
            for index in snapshot.defaultPage.languages.indices {
                snapshot.defaultPage.languages[index].approvedKeywords = []
            }
        }
        return snapshot
    }

    func submit(versionID _: String, of _: StoreApp) async throws {}
}
#endif
