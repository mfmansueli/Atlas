//
//  OfferCodeCodesRetryTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// An offer code's custom code and one-time codes tried again after Apple
/// didn't answer: the push reads the offer code's codes first and carries
/// on with the ones it made, never making them twice, and never takes an
/// older batch like its own for it (`OfferCodeCodesCreate`).
@MainActor
@Suite("PushController · offer codes tried again")
struct OfferCodeCodesRetryTests {
    private let queue = ChangeQueue()
    private let history = PushHistory()
    private static let app = NewSubscriptionChangeBuilderTests.app
    private static let monthly = IntroductoryOfferChangeBuilderTests.monthly
    private static let expires = "2099-01-01"
    private static let code = ExistingOfferCode(
        id: "oc1", name: "Podcast", eligibilities: [.new], mode: .freeTrial, duration: .oneMonth
    )

    private func batch(_ count: Int = 50) -> NewOneTimeCodes {
        NewOneTimeCodes(numberOfCodes: count, expirationDate: NewIntroductoryOffer.day(from: Self.expires) ?? .now)
    }

    private func controller(_ transport: FakeOfferCodesTransport) -> PushController {
        PushController(queue: queue, history: history, transport: transport)
    }

    private func push(_ change: PendingChange, with controller: PushController) async {
        queue.upsert(change)
        controller.push(queue.changes)
        await controller.waitUntilFinished()
    }

    private func retry(_ controller: PushController) async {
        controller.retryFailed()
        await controller.waitUntilFinished()
    }

    private func posts(_ transport: FakeOfferCodesTransport, to path: String) -> Int {
        transport.posts.count { $0.path == path }
    }

    // MARK: - Custom codes

    @Test func aCustomCodeAppleMadeBeforeTimingOutIsntMadeAgain() async {
        let transport = FakeOfferCodesTransport(offerCodeID: "oc1", madeButTimedOut: 1)
        let controller = controller(transport)
        let change = OfferCodeChangeBuilder(app: Self.app).customCodeChange(
            NewCustomCode(code: "lumenpod", numberOfCodes: 100), for: Self.code, subscription: Self.monthly
        )
        await push(change, with: controller)
        #expect(controller.doneCount == 0)
        #expect(controller.items.first?.status == .failed(PushController.timedOutText))
        #expect(transport.customCodes.count == 1)

        await retry(controller)
        #expect(controller.doneCount == 1)
        #expect(posts(transport, to: NewCustomCode.path) == 1)
        #expect(transport.customCodes.map(\.id) == ["cc1"])
        #expect(queue.changes.isEmpty)
    }

    @Test func aCustomCodeThatWasntMadeIsPostedAgain() async {
        let transport = FakeOfferCodesTransport(offerCodeID: "oc1", failsBeforeMaking: 1)
        let controller = controller(transport)
        let change = OfferCodeChangeBuilder(app: Self.app).customCodeChange(
            NewCustomCode(code: "LUMENPOD", numberOfCodes: 100), for: Self.code, subscription: Self.monthly
        )
        await push(change, with: controller)
        await retry(controller)
        #expect(controller.doneCount == 1)
        #expect(posts(transport, to: NewCustomCode.path) == 2)
        #expect(transport.customCodes.count == 1)
    }

    // MARK: - One-time codes

    @Test func aBatchAppleMadeBeforeTimingOutIsntMadeAgain() async {
        let transport = FakeOfferCodesTransport(offerCodeID: "oc1", madeButTimedOut: 1)
        let controller = controller(transport)
        let change = OfferCodeChangeBuilder(app: Self.app).oneTimeCodesChange(batch(), for: Self.code, subscription: Self.monthly)
        await push(change, with: controller)
        #expect(controller.doneCount == 0)
        // What the offer code had before the push posted, kept for the retry.
        #expect(controller.items.first?.oneTimeBatchesBefore == ["oc1": []])

        await retry(controller)
        #expect(controller.doneCount == 1)
        #expect(posts(transport, to: NewOneTimeCodes.path) == 1)
        #expect(transport.batches.map(\.id) == ["ot1"])
    }

    @Test func anOlderBatchLikeItIsntTakenForTheOneItMade() async {
        // The offer code already has 50 codes expiring the same day.
        let older = FakeOfferCodesTransport.batch("old1", count: 50, expires: Self.expires)
        let transport = FakeOfferCodesTransport(offerCodeID: "oc1", batches: [older], failsBeforeMaking: 1)
        let controller = controller(transport)
        let change = OfferCodeChangeBuilder(app: Self.app).oneTimeCodesChange(batch(), for: Self.code, subscription: Self.monthly)
        await push(change, with: controller)
        #expect(controller.items.first?.oneTimeBatchesBefore == ["oc1": ["old1"]])

        // Apple didn't make it: the retry posts again instead of taking old1.
        await retry(controller)
        #expect(controller.doneCount == 1)
        #expect(posts(transport, to: NewOneTimeCodes.path) == 2)
        #expect(transport.batches.map(\.id) == ["old1", "ot1"])
        // The first try's note of what was there stays as it was.
        #expect(controller.items.first?.oneTimeBatchesBefore == ["oc1": ["old1"]])
    }

    @Test func aFirstTryPostsEvenWhenAnOlderBatchIsLikeIt() async {
        let older = FakeOfferCodesTransport.batch("old1", count: 50, expires: Self.expires)
        let transport = FakeOfferCodesTransport(offerCodeID: "oc1", batches: [older])
        let controller = controller(transport)
        let change = OfferCodeChangeBuilder(app: Self.app).oneTimeCodesChange(batch(), for: Self.code, subscription: Self.monthly)
        await push(change, with: controller)
        #expect(controller.doneCount == 1)
        #expect(posts(transport, to: NewOneTimeCodes.path) == 1)
        #expect(transport.batches.count == 2)
    }

    @Test func aBatchPushedAgainAfterTheSheetClosedIsntMadeAgain() async {
        let transport = FakeOfferCodesTransport(offerCodeID: "oc1", madeButTimedOut: 1)
        let controller = controller(transport)
        let change = OfferCodeChangeBuilder(app: Self.app).oneTimeCodesChange(batch(), for: Self.code, subscription: Self.monthly)
        await push(change, with: controller)
        controller.dismissFinished()

        // Pushed again from Review & Push: the change sent nothing Apple
        // confirmed, but what the offer code had before is remembered.
        controller.push(queue.changes)
        await controller.waitUntilFinished()
        #expect(controller.doneCount == 1)
        #expect(posts(transport, to: NewOneTimeCodes.path) == 1)
        #expect(transport.batches.count == 1)
    }

    @Test func aNewOfferCodesCustomCodeIsFoundWhenTheChangeGoesOn() async {
        var code = NewOfferCode(name: "Podcast", terms: OfferTerms(mode: .freeTrial, duration: .oneMonth, territories: .chosen(["USA"])))
        code.customCode = NewCustomCode(code: "LUMENPOD", numberOfCodes: 100)
        code.oneTimeCodes = batch()
        // The offer code is made (oc1); Apple makes the custom code but
        // doesn't answer in time.
        let transport = FakeOfferCodesTransport(offerCodeID: "oc1", madeButTimedOut: 1)
        let controller = controller(transport)
        await push(OfferCodeChangeBuilder(app: Self.app).change(for: code, subscription: Self.monthly), with: controller)
        #expect(controller.items.first?.sentRequestCount == 1)
        #expect(posts(transport, to: NewOneTimeCodes.path) == 0)

        await retry(controller)
        #expect(controller.doneCount == 1)
        #expect(posts(transport, to: SubscriptionOfferResource.offerCode.path) == 1)
        #expect(posts(transport, to: NewCustomCode.path) == 1)
        #expect(posts(transport, to: NewOneTimeCodes.path) == 1)
        #expect(transport.customCodes.count == 1)
        #expect(transport.batches.count == 1)
    }
}
