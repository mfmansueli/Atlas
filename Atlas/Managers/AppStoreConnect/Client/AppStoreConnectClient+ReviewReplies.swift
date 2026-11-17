//
//  AppStoreConnectClient+ReviewReplies.swift
//  Atlas
//

import Foundation

/// Ratings & Reviews: the reviews with their replies, and the replies the
/// person sends. Replies are the only writes, each after Send Reply.
extension AppStoreConnectClient {
    /// One page of the app's reviews, newest first, each with its reply
    /// (`GET /v1/apps/{id}/customerReviews?include=response`). `next`
    /// continues from an earlier page's link.
    func customerReviewsPage(appID: String, next: URL? = nil, limit: Int = 200) async throws -> CustomerReviewsDocument {
        let first = url("/v1/apps/\(appID)/customerReviews", query: [
            URLQueryItem(name: "sort", value: "-createdDate"),
            URLQueryItem(name: "limit", value: String(min(limit, 200))),
            URLQueryItem(name: "include", value: "response"),
            URLQueryItem(name: "fields[customerReviews]", value: "rating,title,body,reviewerNickname,createdDate,territory,response"),
            URLQueryItem(name: "fields[customerReviewResponses]", value: "responseBody,lastModifiedDate,state"),
        ])
        return try await get(next ?? first)
    }

    /// The ids of the newest reviews listed under one version
    /// (`GET /v1/appStoreVersions/{id}/customerReviews`), up to 200.
    func versionReviewIDs(versionID: String) async throws -> [String] {
        let page: AppStoreConnectPage<CustomerReviewAttributes> = try await get(url("/v1/appStoreVersions/\(versionID)/customerReviews", query: [
            URLQueryItem(name: "sort", value: "-createdDate"),
            URLQueryItem(name: "limit", value: "200"),
            URLQueryItem(name: "fields[customerReviews]", value: "rating"),
        ]))
        return page.data.map(\.id)
    }

    /// Replies to a review, or replaces the reply it has
    /// (`POST /v1/customerReviewResponses`).
    func createReviewResponse(reviewID: String, body: String) async throws -> AppStoreConnectResource<CustomerReviewResponseAttributes> {
        let document: [String: Any] = ["data": [
            "type": "customerReviewResponses",
            "attributes": ["responseBody": body],
            "relationships": ["review": ["data": ["type": "customerReviews", "id": reviewID]]],
        ]]
        let data = try JSONSerialization.data(withJSONObject: document)
        let response = try await send(PushRequest(method: .post, path: "/v1/customerReviewResponses", body: data))
        do {
            return try JSONDecoder().decode(CustomerReviewResponseDocument.self, from: response.data).data
        } catch {
            throw AppStoreConnectError.unexpectedPayload
        }
    }

    /// Takes a reply off the App Store (`DELETE /v1/customerReviewResponses/{id}`).
    func deleteReviewResponse(id: String) async throws {
        _ = try await send(PushRequest(method: .delete, path: "/v1/customerReviewResponses/\(id)", body: nil))
    }
}
