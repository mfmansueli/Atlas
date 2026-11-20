//
//  WorkspaceServices+KeptProductPages.swift
//  Atlas
//

import Foundation

extension WorkspaceServices {
    /// The same services, with product pages answered from `kept` when it
    /// has the app's (`KeptProductPagesServices`): what `MainView` gives
    /// assistant tools.
    func keepingProductPages(_ kept: @escaping @MainActor (StoreApp.ID) -> ProductPagesSnapshot?) -> WorkspaceServices {
        var services = self
        services.productPages = KeptProductPagesServices(base: productPages, kept: kept)
        return services
    }
}
