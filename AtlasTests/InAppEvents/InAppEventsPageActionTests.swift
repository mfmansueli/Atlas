//
//  InAppEventsPageActionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// New Event… in the toolbar (board 80): on once the events are read, also
/// with none, and it opens New Event's sheet.
@MainActor
@Suite("In-App Events · page action")
struct InAppEventsPageActionTests {
    typealias Data = InAppEventsTestData

    private func makeModel(_ events: [InAppEvent], load: Bool = true) async -> InAppEventsViewModel {
        let model = InAppEventsViewModel(app: Data.app, services: FakeInAppEventsServices(events), store: InAppEventsStore(), queue: ChangeQueue())
        model.now = { Data.now }
        model.linkClaims = ProjectLinkClaimsCenter()
        if load { await model.load() }
        return model
    }

    @Test func beforeTheReadItsOff() async {
        let model = await makeModel(Data.events, load: false)
        #expect(model.pageActionState == .disabled(reason: nil))
        model.startPageAction()
        #expect(!model.isNewEventPresented)
    }

    @Test(arguments: [true, false])
    func onceReadItOpensTheSheet(withEvents: Bool) async {
        let model = await makeModel(withEvents ? Data.events : [])
        #expect(model.pageActionState == .enabled)
        model.startPageAction()
        #expect(model.isNewEventPresented)
    }
}
