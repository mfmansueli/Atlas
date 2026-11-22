//
//  ScreenshotHandSetTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// One language's set on one device changed by hand: replace, delete,
/// add, move and Undo Change, and when it's the template's again.
@Suite("ScreenshotHandSet")
struct ScreenshotHandSetTests {
    private typealias Files = ScreenshotHandTestFiles

    @Test func aSetAsItStartsIsUnchanged() {
        let set = Files.templateSet()
        #expect(set.isUnchanged(from: (0..<5).map { .template(slot: $0) }))
        #expect(set.keptCount == 5)
        #expect(set.room == 5)
    }

    @Test func replacingPutsTheFileInItsPlace() {
        var set = Files.templateSet()
        let id = set.slots[1].id
        let done1 = set.replace(id, with: Files.file("a"))
        #expect(done1)
        #expect(set.slots[1].file?.id == "a")
        #expect(set.slots[1].origin == .uploaded)
        #expect(set.slots[1].isChanged)
        #expect(!set.isUnchanged(from: (0..<5).map { .template(slot: $0) }))
    }

    @Test func replacingByPositionSkipsDeletedPlaces() {
        var set = Files.templateSet()
        set.delete(set.slots[0].id)
        let done2 = set.replace(position: 0, with: Files.file("a"))
        #expect(done2)
        #expect(set.slots[1].file?.id == "a")
        #expect(set.slots[0].file == nil)
    }

    @Test func deletingMarksItAndOneAddedByHandJustGoes() {
        var set = Files.templateSet()
        set.delete(set.slots[2].id)
        #expect(set.slots[2].isDeleted)
        #expect(set.keptCount == 4)
        set.add([Files.file("new")])
        #expect(set.slots.count == 6)
        set.delete(set.slots[5].id)
        #expect(set.slots.count == 5)
    }

    @Test func deleteAllLeavesNothing() {
        var set = Files.templateSet()
        set.add([Files.file("new")])
        set.deleteAll()
        #expect(set.keptCount == 0)
        #expect(set.slots.count == 5)
        let all3 = set.slots.allSatisfy(\.isDeleted)
        #expect(all3)
    }

    @Test func addingStopsAtTen() {
        var set = Files.templateSet(count: 8)
        let added = set.add((0..<5).map { Files.file("f\($0)") })
        #expect(added == 2)
        #expect(set.keptCount == 10)
        #expect(set.room == 0)
    }

    @Test func movingSwapsWithTheNeighbor() {
        var set = Files.templateSet()
        let first = set.slots[0].id
        let done4 = set.move(first, by: 1)
        #expect(done4)
        #expect(set.slots[1].id == first)
        let done5 = set.move(set.slots[4].id, by: 1)
        #expect(!done5)
        let done6 = set.swap(set.slots[0].id, set.slots[4].id)
        #expect(done6)
        #expect(set.slots.map(\.base) != (0..<5).map { .template(slot: $0) })
    }

    @Test func undoBringsTheTemplateBackAndForgetsAnAddedFile() {
        var set = Files.templateSet()
        let id = set.slots[1].id
        set.replace(id, with: Files.file("a"))
        let done7 = set.undo(id)
        #expect(done7)
        #expect(set.slots[1].file == nil)
        set.delete(id)
        let done8 = set.undo(id)
        #expect(done8)
        #expect(!set.slots[1].isDeleted)
        set.add([Files.file("b")])
        let done9 = set.undo(set.slots[5].id)
        #expect(done9)
        #expect(set.slots.count == 5)
        #expect(set.isUnchanged(from: (0..<5).map { .template(slot: $0) }))
    }

    @Test func deletedPlacesAreForgottenOnceGone() {
        var set = Files.templateSet()
        let id = set.slots[3].id
        set.delete(id)
        set.dropDeleted([id])
        #expect(set.slots.count == 4)
        #expect(set.index(of: id) == nil)
    }

    @Test func theDocumentForgetsASetBackToHowItStarts() {
        var document = ScreenshotsDebugDocuments.standard
        let live = ScreenshotsDebugDocuments.live
        var set = document.handSetOrStart(locale: "ja", displayType: .iPhone, live: live)
        set.replace(set.slots[0].id, with: Files.file("a"))
        document.storeHandSet(set, live: live)
        #expect(document.hasHandSets)
        #expect(document.handFileIDs == ["a"])
        set.undo(set.slots[0].id)
        document.storeHandSet(set, live: live)
        #expect(!document.hasHandSets)
    }

    @Test func aLanguageOutsideTheScopeStartsFromItsLiveScreenshots() {
        let document = ScreenshotsDebugDocuments.standard
        let bases = document.startingHandBases(locale: "en-GB", displayType: .iPhone, live: ScreenshotsDebugDocuments.live)
        #expect(bases.count == 5)
        #expect(bases.allSatisfy { $0.liveID != nil })
        #expect(document.startingHandBases(locale: "pl", displayType: .iPhone, live: ScreenshotsDebugDocuments.live).isEmpty)
    }
}
#endif
