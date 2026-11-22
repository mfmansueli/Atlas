//
//  PushControllerAppPriceAvailabilityTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Pushing the app's price and first availability: each is one `POST`, and
/// a refusal says what usually causes it with Apple's words.
@MainActor
@Suite("PushController · app price and availability")
struct PushControllerAppPriceAvailabilityTests {
    private let queue = ChangeQueue()
    private let history = PushHistory()
    private let app = AppPriceChangeBuilderTests.app

    private func push(_ changes: [PendingChange], via transport: FakePushTransport) async -> PushController {
        let controller = PushController(queue: queue, history: history, transport: transport)
        queue.upsert(contentsOf: changes)
        controller.push(queue.changes)
        await controller.waitUntilFinished()
        return controller
    }

    private var price: PendingChange {
        AppPriceChangeBuilder(app: app).change(point: AppPriceChangeBuilderTests.paid, in: .unitedStates, replacing: .notSet)
    }

    private var availability: PendingChange {
        AppAvailabilityChangeBuilder(app: app).setupChange(.everywhere(["USA", "BRA"]))
    }

    @Test func thePriceAndAvailabilityGoAsTheyWereQueued() async {
        let transport = FakePushTransport()
        let controller = await push([price, availability], via: transport)

        #expect(controller.doneCount == 2)
        #expect(queue.changes.isEmpty)
        #expect(Set(transport.sent.map(\.path)) == ["/v1/appPriceSchedules", "/v2/appAvailabilities"])
        #expect(transport.sent.allSatisfy { $0.method == .post })
        let schedule = transport.sent.first { $0.path == "/v1/appPriceSchedules" }
        #expect(schedule.flatMap(AppPriceAvailabilityRequests.priceSchedule(in:))?.pricePointID == "pp-299")
    }

    @Test func aRefusedPaidPriceNamesTheAgreement() async throws {
        let refusal = AppStoreConnectError.forbidden(detail: "The Paid Applications agreement is not in effect.")
        let transport = FakePushTransport(failures: ["/v1/appPriceSchedules": refusal])
        let controller = await push([price], via: transport)

        let item = try #require(controller.items.first)
        guard case let .failed(message) = item.status else {
            Issue.record("Expected a failure, got \(item.status)")
            return
        }
        #expect(message.contains("Paid Applications agreement to be active"))
        #expect(message.contains("FORBIDDEN_ERROR — The Paid Applications agreement is not in effect."))
        #expect(queue.change(id: price.id) != nil)
    }

    @Test func aRefusedAvailabilitySaysToRefresh() async throws {
        let refusal = AppStoreConnectError.rejected(statusCode: 409, code: "ENTITY_ERROR", detail: "An availability already exists.")
        let transport = FakePushTransport(createFailures: ["/v2/appAvailabilities": refusal])
        let controller = await push([availability], via: transport)

        guard case let .failed(message) = try #require(controller.items.first).status else {
            Issue.record("Expected a failure")
            return
        }
        #expect(message.contains("refresh Pricing"))
        #expect(message.contains("ENTITY_ERROR — An availability already exists."))
    }

    @Test func onlyApplesRefusalsAreExplained() {
        #expect(AppPriceAvailabilityRefusal(kind: .price, error: .rateLimited) == nil)
        #expect(AppPriceAvailabilityRefusal(kind: .price, error: .unauthorized) == nil)
        #expect(AppPriceAvailabilityRefusal(kind: .price, error: .server(statusCode: 500, detail: nil)) == nil)
        #expect(AppPriceAvailabilityRefusal(kind: .price, error: .server(statusCode: 400, code: "PARAMETER_ERROR", detail: nil)) != nil)
    }

    @Test func otherRequestsArentTheseWrites() {
        let patch = AppPriceAvailabilityRequests.territory("ta1", available: false)
        #expect(AppPriceAvailabilityWrite(patch) == nil)
        #expect(AppPriceAvailabilityWrite(PushRequest(method: .post, path: "/v1/subscriptionPrices", body: nil)) == nil)
        #expect(AppPriceAvailabilityWrite(price.requests[0])?.kind == .price)
        #expect(AppPriceAvailabilityWrite(availability.requests[0])?.kind == .availability)
    }
}
