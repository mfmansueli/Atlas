//
//  AppStoreConnectClient+SalesReports.swift
//  Atlas
//

import Foundation

/// Sales and Trends: one day's report for the whole vendor, as the gzip
/// file Apple sends.
extension AppStoreConnectClient {
    /// nil when Apple has no report for that day (404: nothing sold, or not
    /// made yet).
    func salesReport(vendorNumber: String, type: String, subType: String, version: String, date: String) async throws -> Data? {
        var request = URLRequest(url: url("/v1/salesReports", query: [
            URLQueryItem(name: "filter[frequency]", value: "DAILY"),
            URLQueryItem(name: "filter[reportType]", value: type),
            URLQueryItem(name: "filter[reportSubType]", value: subType),
            URLQueryItem(name: "filter[vendorNumber]", value: vendorNumber),
            URLQueryItem(name: "filter[version]", value: version),
            URLQueryItem(name: "filter[reportDate]", value: date),
        ]))
        try request.setValue("Bearer \(AppStoreConnectJWT.token(for: credentials, issuedAt: now()))", forHTTPHeaderField: "Authorization")
        request.setValue("application/a-gzip", forHTTPHeaderField: "Accept")
        let (data, response) = try await transport.send(request)
        guard let http = response as? HTTPURLResponse else { throw AppStoreConnectError.invalidResponse }
        if http.statusCode == 404 { return nil }
        guard (200..<300).contains(http.statusCode) else { throw AppStoreConnectError(statusCode: http.statusCode, body: data) }
        return data
    }
}
