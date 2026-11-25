//
//  StoreArtworkMenuTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Add ▾ and Edit ▾: what each tile's one button offers.
@Suite("Store artwork menu")
struct StoreArtworkMenuTests {
    private typealias Fixtures = StoreArtworkFixtures

    @Test func addOffersTheFileAndAutopilotOnPro() {
        let header = StoreArtworkSlot(place: .header, locale: "fr-FR", live: nil, extras: nil)
        #expect(header.menuItems.map(\.action) == [.add, .makeWithAutopilot])
        #expect(header.menuItems.map(\.title) == ["Add Header…", "Make with Autopilot…"])
        #expect(header.menuItems.map(\.isPro) == [false, true])
        let search = StoreArtworkSlot(place: .search, locale: "fr-FR", live: nil, extras: nil)
        #expect(search.menuItems.first?.title == "Add Search Artwork…")
    }

    @Test func editOffersReplaceMakeAndDeleteWithoutUndoWhenLive() {
        let slot = StoreArtworkSlot(place: .header, locale: "de-DE", live: Fixtures.live(.header), extras: nil)
        #expect(slot.menuItems.map(\.action) == [.replace, .makeNew, .delete])
        #expect(slot.menuItems.map(\.title) == ["Replace…", "Make a New One…", "Delete…"])
        let delete = slot.menuItems[2]
        #expect(delete.isDestructive)
        #expect(delete.startsGroup)
        #expect(slot.menuItems[1].isPro)
    }

    @Test func aChangeWaitingAddsUndoChange() {
        let slot = StoreArtworkSlot(place: .search, locale: "de-DE", live: nil, extras: Fixtures.extras([Fixtures.handFile(.search)]))
        #expect(slot.menuItems.map(\.action) == [.replace, .makeNew, .delete, .undo])
        #expect(slot.menuItems.last?.title == "Undo Change")
    }

    @Test func aDeletionOffersOnlyUndo() {
        var extras = Fixtures.extras()
        extras.markRemoval(.search, locale: "de-DE", at: Fixtures.date)
        let slot = StoreArtworkSlot(place: .search, locale: "de-DE", live: Fixtures.live(.search), extras: extras)
        #expect(slot.menuItems.map(\.action) == [.undo])
        #expect(slot.buttonTitle == "Edit")
    }
}
#endif
