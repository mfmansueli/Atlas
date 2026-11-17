//
//  AppStoreConnectClient+Analytics.swift
//  Atlas
//

import Foundation

/// The Analytics Reports API: ask Apple to make an app's reports, then walk
/// request → reports → instances → segments and download the files.
extension AppStoreConnectClient {
    func analyticsReportRequests(appID: String) async throws -> [AppStoreConnectResource<AnalyticsReportRequestAttributes>] {
        try await allPages(of: "/v1/apps/\(appID)/analyticsReportRequests", query: [
            URLQueryItem(name: "fields[analyticsReportRequests]", value: "accessType,stoppedDueToInactivity"),
            URLQueryItem(name: "limit", value: "200"),
        ])
    }

    /// Asks Apple to make reports for the app. Only an Admin key may; any
    /// other role gets 403.
    func createAnalyticsReportRequest(appID: String, accessType: String) async throws {
        let body: [String: Any] = ["data": [
            "type": "analyticsReportRequests",
            "attributes": ["accessType": accessType],
            "relationships": ["app": ["data": ["type": "apps", "id": appID]]],
        ]]
        let data = try JSONSerialization.data(withJSONObject: body)
        _ = try await send(PushRequest(method: .post, path: "/v1/analyticsReportRequests", body: data))
    }

    func deleteAnalyticsReportRequest(id: String) async throws {
        _ = try await send(PushRequest(method: .delete, path: "/v1/analyticsReportRequests/\(id)", body: nil))
    }

    func analyticsReports(requestID: String, category: String) async throws -> [AppStoreConnectResource<AnalyticsReportAttributes>] {
        try await allPages(of: "/v1/analyticsReportRequests/\(requestID)/reports", query: [
            URLQueryItem(name: "filter[category]", value: category),
            URLQueryItem(name: "limit", value: "200"),
        ])
    }

    func analyticsReportInstances(
        reportID: String, granularity: String = "DAILY"
    ) async throws -> [AppStoreConnectResource<AnalyticsReportInstanceAttributes>] {
        try await allPages(of: "/v1/analyticsReports/\(reportID)/instances", query: [
            URLQueryItem(name: "filter[granularity]", value: granularity),
            URLQueryItem(name: "limit", value: "200"),
        ])
    }

    func analyticsReportSegments(instanceID: String) async throws -> [AppStoreConnectResource<AnalyticsReportSegmentAttributes>] {
        try await allPages(of: "/v1/analyticsReportInstances/\(instanceID)/segments", query: [URLQueryItem(name: "limit", value: "200")])
    }

    /// One segment's file. The URL is signed already, so it goes without
    /// the API key.
    func downloadAnalyticsSegment(_ url: URL) async throws -> Data {
        let (data, response) = try await transport.send(URLRequest(url: url))
        guard let http = response as? HTTPURLResponse else { throw AppStoreConnectError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw AppStoreConnectError(statusCode: http.statusCode, body: data) }
        return data
    }
}
