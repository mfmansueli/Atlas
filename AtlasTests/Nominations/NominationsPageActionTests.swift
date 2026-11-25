//
//  NominationsPageActionTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// New Nomination… in the toolbar (board 80): on once the nominations are
/// read, off with why for a key that can't create them, and it opens a new
/// draft.
@MainActor
@Suite("Nominations · page action")
struct NominationsPageActionTests {
    typealias Data = DebugNominationsData

    private let store = NominationsStore()

    private func model(load: Bool = true) async -> NominationsViewModel {
        store.load(Data.archive(), for: Data.lumen)
        let model = NominationsViewModel(app: DebugFixtures.lumen, services: DebugNominationsServices(), store: store, queue: ChangeQueue())
        model.now = { Data.now }
        if load { _ = await model.load() }
        return model
    }

    @Test func beforeTheReadItsOff() async {
        let model = await model(load: false)
        #expect(model.pageActionState == .disabled(reason: nil))
    }

    @Test func itOpensANewDraft() async throws {
        let model = await model()
        #expect(model.pageActionState == .enabled)
        model.startPageAction()
        let draft = try #require(model.selectedNomination)
        #expect(draft.isEditable)
        #expect(draft.id != Data.draftID)
    }

    @Test func aKeyThatCantWriteSaysWhy() async {
        let model = await model()
        model.problem = .keyRole
        #expect(model.pageActionState == .disabled(reason: "This key can’t create nominations"))
        model.startPageAction()
        #expect(model.selectedNomination == nil)
    }
}
