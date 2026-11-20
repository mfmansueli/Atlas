//
//  MCPWorkspace+ProductPages.swift
//  Atlas
//

import Foundation

extension MCPWorkspace {
    /// An app's custom product pages and its default page. `MainView` gives
    /// the workspace services that answer with what the Product Pages
    /// section read while that's fresh (`KeptProductPagesServices`), else
    /// they read App Store Connect.
    func productPages(for app: StoreApp) async throws -> ProductPagesSnapshot {
        do {
            return try await services.productPages.pages(for: app)
        } catch {
            throw MCPToolError.unavailable(String(localized: """
            Atlas couldn’t read \(app.name)’s product pages from App Store Connect: \(error.localizedDescription)
            """))
        }
    }
}
