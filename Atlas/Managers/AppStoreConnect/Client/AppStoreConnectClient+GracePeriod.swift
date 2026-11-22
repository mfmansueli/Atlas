//
//  AppStoreConnectClient+GracePeriod.swift
//  Atlas
//

import Foundation

/// Billing Grace Period: people keep their subscription while Apple
/// retries a failed charge. One setting per app, read and changed through
/// its own resource (OpenAPI 4.6).
extension AppStoreConnectClient {
    /// The app's setting (`GET /v1/apps/{id}/subscriptionGracePeriod`);
    /// nil when the app has none.
    func subscriptionGracePeriod(appID: String) async throws -> AppInformationResourceDocument<SubscriptionGracePeriodAttributes>.Resource? {
        do {
            let document: AppInformationResourceDocument<SubscriptionGracePeriodAttributes> = try await get(
                url("/v1/apps/\(appID)/subscriptionGracePeriod")
            )
            return document.data
        } catch AppStoreConnectError.notFound {
            return nil
        }
    }

    /// Turns it on for production, for `duration`, for every renewal
    /// (`PATCH /v1/subscriptionGracePeriods/{id}`).
    func turnOnSubscriptionGracePeriod(id: String, duration: String) async throws {
        let document: [String: Any] = ["data": [
            "type": "subscriptionGracePeriods", "id": id,
            "attributes": ["optIn": true, "duration": duration, "renewalType": "ALL_RENEWALS"],
        ]]
        let data = try JSONSerialization.data(withJSONObject: document)
        _ = try await send(PushRequest(method: .patch, path: "/v1/subscriptionGracePeriods/\(id)", body: data))
    }
}
