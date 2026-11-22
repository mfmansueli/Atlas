//
//  ScreenshotHandPlannerTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// What a push sends for a set changed by hand: the file uploaded into its
/// place, the live screenshots nothing keeps deleted after the uploads,
/// and the new order when only the order changed.
@MainActor
@Suite("ScreenshotHandPlanner")
struct ScreenshotHandPlannerTests {
    private typealias Fixtures = ScreenshotPushTestFixtures
    private typealias Files = ScreenshotHandTestFiles

    private func plan(state: ScreenshotPushState = ScreenshotPushState(), _ change: (inout ScreenshotHandSet) -> Void) -> ScreenshotPushPlan {
        var document = ScreenshotsDebugDocuments.standard
        var set = document.handSetOrStart(locale: "ja", displayType: .iPhone, live: ScreenshotsDebugDocuments.live)
        change(&set)
        document.setHandSet(set, locale: "ja", displayType: .iPhone)
        return ScreenshotPushPlanner().plan(Fixtures.input(document: document, state: state))
    }

    private func japanese(_ plan: ScreenshotPushPlan) throws -> ScreenshotPlanGroup {
        try #require(plan.groups.first { $0.locale.code == "ja" && $0.displayType == .iPhone })
    }

    @Test func aReplacedScreenshotUploadsTheFileAndDeletesTheOldOne() throws {
        let group = try japanese(plan { $0.replace(position: 1, with: Files.file("a")) })
        #expect(group.isHand)
        let upload = try #require(group.items.first { $0.content == .file(Files.file("a")) })
        #expect(upload.cell.slot == 1)
        let delete = try #require(group.items.first { $0.content == .delete })
        #expect(delete.old?.id == "live|ja|\(ScreenshotDisplayType.iPhone.rawValue)|1")
        #expect(!group.items.contains { $0.content == .reorder })
        #expect(group.arrangement?.count == 5)
        #expect(group.arrangement?[1] == .upload(itemID: upload.id))
        #expect(group.countTitle == "1 image, 1 delete")
    }

    @Test func otherLanguagesPlanAsBefore() {
        let before = ScreenshotPushPlanner().plan(Fixtures.input())
        let after = plan { $0.replace(position: 1, with: Files.file("a")) }
        #expect(after.groups.filter { $0.locale.code != "ja" }.map(\.items) == before.groups.filter { $0.locale.code != "ja" }.map(\.items))
    }

    @Test func aDeleteOnlyDeletes() throws {
        let group = try japanese(plan { $0.delete(position: 4) })
        #expect(group.items.map(\.content) == [.delete])
        #expect(group.deleteCount == 1)
        #expect(group.countTitle == "1 delete")
    }

    @Test func movingTwoAsksForTheNewOrder() throws {
        let group = try japanese(plan { set in set.swap(set.slots[0].id, set.slots[1].id) })
        let order = try #require(group.items.first { $0.content == .reorder })
        #expect(order.handOrder.prefix(2) == ["live|ja|\(ScreenshotDisplayType.iPhone.rawValue)|1", "live|ja|\(ScreenshotDisplayType.iPhone.rawValue)|0"])
        #expect(group.items.count == 1)
    }

    @Test func aDiscardedFileStaysOutUntilItChanges() throws {
        let first = plan { $0.replace(position: 1, with: Files.file("a")) }
        let upload = try #require(first.items.first { $0.content.handFile != nil })
        var state = ScreenshotPushState()
        state.keptHand = try [upload.id: #require(upload.handFingerprint)]
        let kept = plan(state: state) { $0.replace(position: 1, with: Files.file("a")) }
        #expect(!kept.items.contains { $0.content.handFile != nil })
        let changed = plan(state: state) { $0.replace(position: 1, with: Files.file("b")) }
        #expect(changed.items.contains { $0.content.handFile?.id == "b" })
    }

    @Test func theNewOrderPutsUploadsInTheirPlaces() {
        let order = ScreenshotSetProgress.handOrder([.keep(liveID: "a"), .upload(itemID: "x"), .keep(liveID: "c")], order: ["a", "c", "new", "b"]) {
            $0 == "x" ? "new" : nil
        }
        #expect(order == ["a", "new", "c", "b"])
    }
}
#endif
