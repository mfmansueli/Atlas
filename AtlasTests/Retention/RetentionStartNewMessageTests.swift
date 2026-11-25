//
//  RetentionStartNewMessageTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Analytics' Try an Offer Message… opens Pricing → Retention with a new
/// message: right away once the messages are read, else after they are.
@MainActor
@Suite("Retention · a new message from Analytics")
struct RetentionStartNewMessageTests {
    private typealias Fixtures = RetentionTestFixtures

    private func model() -> RetentionModel {
        RetentionModel(app: Fixtures.app, services: DebugRetentionServices(), queue: ChangeQueue(), store: RetentionDraftStore())
    }

    @Test func onceReadItStartsAMessageRightAway() async {
        let model = model()
        await model.load(subscriptions: [Fixtures.monthly, Fixtures.annual])
        model.startNewMessage()
        #expect(model.messages.count == 2)
        #expect(model.selectedMessage?.isNew == true)
        #expect(!model.startsNewMessageAfterLoad)
    }

    @Test func beforeTheReadItWaitsAndNumbersItAfterTheLiveOnes() async {
        let model = model()
        model.startNewMessage()
        #expect(model.messages.isEmpty)
        #expect(model.startsNewMessageAfterLoad)
        await model.load(subscriptions: [Fixtures.monthly, Fixtures.annual])
        #expect(model.messages.count == 2)
        #expect(model.selectedMessage?.isNew == true)
        #expect(model.messages.first?.referenceName == "Before you go")
        #expect(!model.startsNewMessageAfterLoad)
    }
}
#endif
