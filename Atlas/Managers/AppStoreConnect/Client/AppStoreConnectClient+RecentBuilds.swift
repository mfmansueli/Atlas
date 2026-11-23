//
//  AppStoreConnectClient+RecentBuilds.swift
//  Atlas
//

import Foundation

/// Export Compliance's look at the app's newest uploads: whether they
/// arrived with their encryption answer already set.
extension AppStoreConnectClient {
    /// The app's newest builds of any version, newest first
    /// (`GET /v1/builds?filter[app]=…&sort=-uploadedDate`).
    func recentBuilds(appID: String, limit: Int = 5) async throws -> [AppStoreConnectResource<BuildAttributes>] {
        let query = [
            URLQueryItem(name: "filter[app]", value: appID),
            URLQueryItem(name: "sort", value: "-uploadedDate"),
            URLQueryItem(name: "fields[builds]", value: "version,uploadedDate,processingState,expired,usesNonExemptEncryption"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        let page: AppStoreConnectPage<BuildAttributes> = try await get(url("/v1/builds", query: query))
        return page.data
    }
}
