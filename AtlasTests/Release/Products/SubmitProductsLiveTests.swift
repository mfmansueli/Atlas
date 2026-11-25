//
//  SubmitProductsLiveTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Subscriptions and in-app purchases Ready to Submit go with the version:
/// which ones are offered, and the requests Submit sends for them.
@MainActor
@Suite("Release · Products submitted with the version")
struct SubmitProductsLiveTests {
    private static let done = CannedHTTPResponse(statusCode: 200, body: #"{"data":{"type":"x","id":"x"}}"#)
    private static let created = CannedHTTPResponse(statusCode: 201, body: #"{"data":{"type":"x","id":"x"}}"#)
    private static let createdSubmission = CannedHTTPResponse(statusCode: 201, body: #"{"data":{"type":"reviewSubmissions","id":"sub1"}}"#)
    private static let none = CannedHTTPResponse(statusCode: 200, body: #"{"data":null}"#)
    private static let noneOpen = CannedHTTPResponse(statusCode: 200, body: #"{"data":[]}"#)
    private static let refused = CannedHTTPResponse(
        statusCode: 409, body: #"{"errors":[{"status":"409","code":"STATE_ERROR","title":"Not allowed","detail":"It can't be submitted now."}]}"#
    )

    private static func state(_ state: String) -> CannedHTTPResponse {
        CannedHTTPResponse(statusCode: 200, body: #"{"data":{"type":"x","id":"x","attributes":{"state":"\#(state)"}}}"#)
    }

    private static let annual = SubmissionProduct(id: "s1", productID: "lumen.plus.annual", name: "Annual", isSubscription: true, isFirst: true)
    private static let lifetime = SubmissionProduct(id: "p1", productID: "lumen.lifetime", name: "Lifetime", isSubscription: false)

    private func services(_ transport: FakeHTTPTransport) -> LiveReleaseServices {
        LiveReleaseServices(client: AppStoreConnectClient(credentials: TestKeys.credentials(), transport: transport))
    }

    private func plan(_ products: [SubmissionProduct]) -> SubmissionPlan {
        SubmissionPlan(
            appID: "42", versionID: "v14", platform: "IOS", buildID: "b212", attachedBuildID: "b212", usesNonExemptEncryption: nil,
            timing: .manual, isPhased: true, products: products
        )
    }

    private func calls(_ transport: FakeHTTPTransport) -> [String] {
        transport.requests.filter { $0.httpMethod != "GET" }.map { "\($0.httpMethod ?? "") \($0.url?.path() ?? "")" }
    }

    private func relationship(_ request: URLRequest, _ name: String) -> String? {
        let object = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
        let data = object?["data"] as? [String: Any]
        let relationship = (data?["relationships"] as? [String: Any])?[name] as? [String: Any]
        return (relationship?["data"] as? [String: Any])?["id"] as? String
    }

    @Test func readyProductsAreSubmittedBeforeTheSubmissionIsSent() async throws {
        let transport = FakeHTTPTransport(
            [Self.done, Self.done, Self.createdSubmission, Self.done, Self.created, Self.created, Self.done],
            routes: [
                ("v14/appStoreVersionPhasedRelease", Self.none), ("/apps/42/reviewSubmissions", Self.noneOpen),
                ("/v1/subscriptions/s1", Self.state("READY_TO_SUBMIT")), ("/v2/inAppPurchases/p1", Self.state("READY_TO_SUBMIT")),
            ]
        )
        try await services(transport).submit(plan([Self.annual, Self.lifetime]))
        #expect(calls(transport) == [
            "PATCH /v1/appStoreVersions/v14",
            "POST /v1/appStoreVersionPhasedReleases",
            "POST /v1/reviewSubmissions",
            "POST /v1/reviewSubmissionItems",
            "POST /v1/subscriptionSubmissions",
            "POST /v1/inAppPurchaseSubmissions",
            "PATCH /v1/reviewSubmissions/sub1",
        ])
        let writes = transport.requests.filter { $0.httpMethod == "POST" }
        let subscription = try #require(writes.first { $0.url?.path() == "/v1/subscriptionSubmissions" })
        let purchase = try #require(writes.first { $0.url?.path() == "/v1/inAppPurchaseSubmissions" })
        #expect(relationship(subscription, "subscription") == "s1")
        #expect(relationship(purchase, "inAppPurchaseV2") == "p1")
    }

    /// A try after a refusal at sending: the product an earlier try
    /// submitted isn't sent again.
    @Test func oneAlreadySubmittedIsntSentAgain() async throws {
        let transport = FakeHTTPTransport(
            [Self.done, Self.done, Self.createdSubmission, Self.done, Self.done],
            routes: [
                ("v14/appStoreVersionPhasedRelease", Self.none), ("/apps/42/reviewSubmissions", Self.noneOpen),
                ("/v1/subscriptions/s1", Self.state("WAITING_FOR_REVIEW")),
            ]
        )
        try await services(transport).submit(plan([Self.annual]))
        #expect(!calls(transport).contains("POST /v1/subscriptionSubmissions"))
        #expect(calls(transport).last == "PATCH /v1/reviewSubmissions/sub1")
    }

    @Test func aRefusedProductStopsBeforeSendingAndSaysWhich() async throws {
        let transport = FakeHTTPTransport(
            [Self.done, Self.done, Self.createdSubmission, Self.done, Self.refused],
            routes: [
                ("v14/appStoreVersionPhasedRelease", Self.none), ("/apps/42/reviewSubmissions", Self.noneOpen),
                ("/v1/subscriptions/s1", Self.state("READY_TO_SUBMIT")),
            ]
        )
        let plan = plan([Self.annual])
        var failure: SubmissionFailure?
        do {
            try await services(transport).submit(plan)
        } catch let error as SubmissionFailure {
            failure = error
        }
        let error = try #require(failure)
        #expect(error.step == .addProduct("s1"))
        #expect(error.submissionID == "sub1")
        #expect(error.hasVersion)
        #expect(!calls(transport).contains("PATCH /v1/reviewSubmissions/sub1"))
        let text = ReleaseViewModel.failureText(error, events: [], plan: plan, versionString: "1.4")
        #expect(text.contains("Subscription “Annual”"))
    }

    @Test func withoutProductsNothingMoreIsSent() async throws {
        let transport = FakeHTTPTransport(
            [Self.done, Self.done, Self.createdSubmission, Self.done, Self.done],
            routes: [("v14/appStoreVersionPhasedRelease", Self.none), ("/apps/42/reviewSubmissions", Self.noneOpen)]
        )
        try await services(transport).submit(plan([]))
        #expect(!calls(transport).contains { $0.contains("Submissions") && !$0.contains("reviewSubmissions") })
    }

    // MARK: - Which are offered

    @Test func onlyReadyToSubmitAreOfferedAndTheFirstOfEachKindIsMarked() {
        let groups = PricingAPIDocument<SubscriptionGroupAttributes>(
            data: [PricingAPIResource(
                type: "subscriptionGroups", id: "g1", attributes: SubscriptionGroupAttributes(referenceName: "Lumen Plus"),
                relationships: ["subscriptions": PricingAPIRelationship(data: .many([
                    PricingAPIIdentifier(type: "subscriptions", id: "s1"), PricingAPIIdentifier(type: "subscriptions", id: "s2"),
                ]))]
            )],
            included: [
                PricingAPIIncluded(
                    type: "subscriptions", id: "s1",
                    attributes: PricingAPIIncluded.Attributes(name: "Annual", productId: "lumen.plus.annual", state: "READY_TO_SUBMIT")
                ),
                PricingAPIIncluded(
                    type: "subscriptions", id: "s2",
                    attributes: PricingAPIIncluded.Attributes(name: "Monthly", productId: "lumen.plus.monthly", state: "APPROVED")
                ),
            ]
        )
        let purchases = [
            PricingAPIResource(type: "inAppPurchases", id: "p1", attributes: InAppPurchaseAttributes(
                name: "Lifetime", productId: "lumen.lifetime", inAppPurchaseType: "NON_CONSUMABLE", state: "READY_TO_SUBMIT"
            )),
            PricingAPIResource(type: "inAppPurchases", id: "p2", attributes: InAppPurchaseAttributes(
                name: "Tips", productId: "lumen.tips", inAppPurchaseType: "CONSUMABLE", state: "MISSING_METADATA"
            )),
        ]
        let offered = LiveReleaseServices.productsToSubmit(groups: groups, purchases: purchases)
        #expect(offered.map(\.id) == ["s1", "p1"])
        #expect(offered.map(\.isFirst) == [false, true])
        #expect(offered.map(\.isSubscription) == [true, false])
    }
}
