//
//  AppStoreConnectClientReviewRepliesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Reading customer reviews with their replies, and replying: the requests
/// App Store Connect gets and how its answers are read.
@MainActor
@Suite("App Store Connect · reviews and replies")
struct AppStoreConnectClientReviewRepliesTests {
    private static let page = CannedHTTPResponse(body: #"""
    {"data":[
      {"type":"customerReviews","id":"r1",
       "attributes":{
         "rating":1,"title":"Sync seit 1.3 kaputt",
         "body":"Seit dem Update synchronisiert iCloud nicht mehr zwischen iPhone und iPad.",
         "reviewerNickname":"mia","createdDate":"2026-11-15T09:30:00-08:00","territory":"DEU"},
       "relationships":{"response":{"data":{"type":"customerReviewResponses","id":"resp1"}}}},
      {"type":"customerReviews","id":"r2",
       "attributes":{
         "rating":5,"title":"Love it","body":"I write in it every single evening, thank you.",
         "reviewerNickname":"sam","createdDate":"2026-11-14T10:00:00Z","territory":"USA"},
       "relationships":{"response":{"data":null}}}
    ],
    "included":[{"type":"customerReviewResponses","id":"resp1","attributes":{
      "responseBody":"Danke!","lastModifiedDate":"2026-11-16T08:00:00Z","state":"PENDING_PUBLISH"}}],
    "links":{
      "self":"https://api.appstoreconnect.apple.com/v1/apps/42/customerReviews",
      "next":"https://api.appstoreconnect.apple.com/v1/apps/42/customerReviews?cursor=abc"},
    "meta":{"paging":{"total":1206,"limit":200}}}
    """#)

    private func client(_ transport: FakeHTTPTransport) -> AppStoreConnectClient {
        AppStoreConnectClient(credentials: TestKeys.credentials(), transport: transport)
    }

    private func query(_ request: URLRequest) -> [String: String] {
        let items = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        return Dictionary(items.map { ($0.name, $0.value ?? "") }) { first, _ in first }
    }

    @Test func reviewsAreReadNewestFirstWithTheirReplies() async throws {
        let transport = FakeHTTPTransport([Self.page])
        let document = try await client(transport).customerReviewsPage(appID: "42")
        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path() == "/v1/apps/42/customerReviews")
        let query = query(request)
        #expect(query["sort"] == "-createdDate")
        #expect(query["limit"] == "200")
        #expect(query["include"] == "response")
        #expect(query["fields[customerReviewResponses]"] == "responseBody,lastModifiedDate,state")

        #expect(document.data.map(\.id) == ["r1", "r2"])
        #expect(document.response(to: document.data[0])?.attributes.responseBody == "Danke!")
        #expect(document.response(to: document.data[1]) == nil)
        #expect(document.links?.next?.query() == "cursor=abc")
        #expect(document.meta?.paging?.total == 1206)
    }

    @Test func thePageCarriesApplesCountOfWrittenReviews() async throws {
        let services = LiveReviewsServices(client: client(FakeHTTPTransport([Self.page])))
        let page = try await services.reviews(for: ReviewsTestData.app, after: nil)
        #expect(page.total == 1206)
        #expect(page.reviews.count == 2)
    }

    @Test func theNextPageIsReadFromItsLink() async throws {
        let transport = FakeHTTPTransport([Self.page])
        let next = try #require(URL(string: "https://api.appstoreconnect.apple.com/v1/apps/42/customerReviews?cursor=abc"))
        _ = try await client(transport).customerReviewsPage(appID: "42", next: next)
        #expect(transport.requests.first?.url == next)
    }

    @Test func aReviewBecomesWhatTheSectionShows() async throws {
        let transport = FakeHTTPTransport([Self.page])
        let document = try await client(transport).customerReviewsPage(appID: "42")
        let german = LiveReviewsServices.review(document.data[0], in: document)
        #expect(german.territory == "DE")
        #expect(german.rating == 1)
        #expect(german.nickname == "mia")
        #expect(german.languageCode == "de")
        #expect(german.date == AppStoreConnectDate.date("2026-11-15T17:30:00Z"))
        #expect(german.reply?.id == "resp1")
        #expect(german.reply?.text == "Danke!")
        #expect(german.reply?.isPending == true)
        #expect(!german.needsReply)

        let english = LiveReviewsServices.review(document.data[1], in: document)
        #expect(english.territory == "US")
        #expect(english.languageCode == "en")
        #expect(english.reply == nil)
        // Five stars: a reply is optional.
        #expect(!english.needsReply)
        #expect(english.replyIsOptional)
    }

    @Test func aReplyIsPostedForItsReview() async throws {
        let created = CannedHTTPResponse(statusCode: 201, body: #"""
        {"data":{"type":"customerReviewResponses","id":"resp9","attributes":{
          "responseBody":"Thanks!","lastModifiedDate":"2026-11-16T12:00:00Z","state":"PENDING_PUBLISH"}}}
        """#)
        let transport = FakeHTTPTransport([created])
        let resource = try await client(transport).createReviewResponse(reviewID: "r2", body: "Thanks!")
        #expect(resource.id == "resp9")
        let reply = LiveReviewsServices.reply(resource, fallbackText: "")
        #expect(reply.text == "Thanks!")
        #expect(reply.isPending)

        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path() == "/v1/customerReviewResponses")
        let body = try #require(request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any])
        let data = try #require(body["data"] as? [String: Any])
        #expect(data["type"] as? String == "customerReviewResponses")
        #expect((data["attributes"] as? [String: Any])?["responseBody"] as? String == "Thanks!")
        let review = ((data["relationships"] as? [String: Any])?["review"] as? [String: Any])?["data"] as? [String: Any]
        #expect(review?["id"] as? String == "r2")
        #expect(review?["type"] as? String == "customerReviews")
    }

    @Test func aReplyIsDeletedByItsID() async throws {
        let transport = FakeHTTPTransport([CannedHTTPResponse(statusCode: 204, body: "")])
        try await client(transport).deleteReviewResponse(id: "resp9")
        let request = try #require(transport.requests.first)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.path() == "/v1/customerReviewResponses/resp9")
    }

    @Test func aRefusedReplyIsAnError() async {
        let forbidden = CannedHTTPResponse(statusCode: 403, body: #"""
        {"errors":[{"status":"403","code":"FORBIDDEN_ERROR","title":"Forbidden","detail":"This key can’t reply."}]}
        """#)
        let transport = FakeHTTPTransport([forbidden])
        await #expect(throws: AppStoreConnectError.self) {
            _ = try await client(transport).createReviewResponse(reviewID: "r2", body: "Thanks!")
        }
    }

    @Test func aVersionsReviewsAreReadByID() async throws {
        let ids = CannedHTTPResponse(body: #"{"data":[{"type":"customerReviews","id":"r1","attributes":{"rating":1}}]}"#)
        let transport = FakeHTTPTransport([ids])
        #expect(try await client(transport).versionReviewIDs(versionID: "v13") == ["r1"])
        #expect(transport.requests.first?.url?.path() == "/v1/appStoreVersions/v13/customerReviews")
    }

    @Test func datesWithAndWithoutFractionsAreRead() {
        #expect(AppStoreConnectDate.date("2026-11-16T12:00:00Z") == Date(timeIntervalSince1970: 1_794_830_400))
        #expect(AppStoreConnectDate.date("2026-11-16T12:00:00.000+00:00") == Date(timeIntervalSince1970: 1_794_830_400))
        #expect(AppStoreConnectDate.date("") == nil)
        #expect(AppStoreConnectDate.date(nil) == nil)
        #expect(AppStoreConnectDate.text(Date(timeIntervalSince1970: 1_794_830_400)) == "2026-11-16T12:00:00Z")
    }
}
