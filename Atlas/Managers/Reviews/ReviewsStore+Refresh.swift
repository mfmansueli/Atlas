//
//  ReviewsStore+Refresh.swift
//  Atlas
//

import Foundation

extension ReviewsStore {
    /// Reads the newest reviews when what's kept is old, for the places
    /// that show reviews without opening the section (the Overview's
    /// card). A failure leaves what's there.
    func refreshIfStale(_ app: StoreApp, services: any ReviewsServices) async {
        guard isStale(app.id), let page = try? await services.reviews(for: app, after: nil) else { return }
        let version = try? await services.currentVersion(for: app)
        setFirstPage(page, currentVersion: version ?? nil, for: app.id)
    }
}
