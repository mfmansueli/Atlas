//
//  ScreenshotHandArrangementTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// An assistant's removal or new order applied to a set as Delete… and
/// ◀ ▶ do: the screenshots it names are found again after the person moved
/// them, the primary language keeps one, and a set that changed under it
/// is refused.
@Suite("ScreenshotHandArrangement")
struct ScreenshotHandArrangementTests {
    private typealias Files = ScreenshotHandTestFiles

    private func arrangement(_ action: ScreenshotHandArrangement.Action, _ positions: [Int], in set: ScreenshotHandSet) -> ScreenshotHandArrangement {
        let places = ScreenshotHandPlace.kept(in: set)
        return ScreenshotHandArrangement(
            id: "ha", client: "Claude Code", receivedAt: .now, locale: set.locale, displayType: set.displayType,
            action: action, places: positions.map { places[$0] }, reason: "Why."
        )
    }

    private func bases(_ set: ScreenshotHandSet) -> [Int?] {
        set.kept.map { $0.base?.templateSlot }
    }

    @Test func aRemovalDeletesTheScreenshotsItNames() throws {
        let set = Files.templateSet()
        let removal = arrangement(.removal, [1, 3], in: set)
        #expect(removal.numbers == "2 and 4")
        let after = try removal.applied(to: set, isPrimary: false).get()
        #expect(bases(after) == [0, 2, 4])
        #expect(after.slots.count(where: \.isDeleted) == 2)
    }

    @Test func itFindsThemAgainAfterTheyMoved() throws {
        var set = Files.templateSet()
        let removal = arrangement(.removal, [0], in: set)
        _ = set.move(set.slots[0].id, by: 2)
        let after = try removal.applied(to: set, isPrimary: false).get()
        #expect(!bases(after).contains(0))
        #expect(after.keptCount == 4)
    }

    @Test func thePrimaryLanguageKeepsOne() {
        let set = Files.templateSet(count: 2)
        let all = arrangement(.removal, [0, 1], in: set)
        #expect(all.applied(to: set, isPrimary: true) == .failure(.lastPrimary))
        #expect((try? all.applied(to: set, isPrimary: false).get())?.keptCount == 0)
    }

    @Test func aScreenshotThatsGoneIsRefused() {
        var set = Files.templateSet()
        let removal = arrangement(.removal, [2], in: set)
        _ = set.replace(set.slots[2].id, with: Files.file("new"))
        #expect(removal.applied(to: set, isPrimary: false) == .failure(.changed))
    }

    @Test func anOrderMovesEveryScreenshot() throws {
        let set = Files.templateSet()
        let order = arrangement(.order, [2, 0, 1, 3, 4], in: set)
        #expect(order.numbers == "3, 1, 2, 4, 5")
        let after = try order.applied(to: set, isPrimary: true).get()
        #expect(bases(after) == [2, 0, 1, 3, 4])
    }

    @Test func anOrderLeavesDeletedPlacesWhereTheyAre() throws {
        var set = Files.templateSet()
        _ = set.delete(set.slots[1].id)
        let order = arrangement(.order, [3, 2, 1, 0], in: set)
        let after = try order.applied(to: set, isPrimary: false).get()
        #expect(after.slots[1].isDeleted)
        #expect(bases(after) == [4, 3, 2, 0])
    }

    @Test func anOrderMustNameEveryOneAndChangeSomething() {
        let set = Files.templateSet()
        #expect(arrangement(.order, [1, 0, 2, 3], in: set).applied(to: set, isPrimary: false) == .failure(.changed))
        #expect(arrangement(.order, [0, 1, 2, 3, 4], in: set).applied(to: set, isPrimary: false) == .failure(.unchanged))
    }

    @Test func placesAreNamedForMCP() {
        var set = Files.templateSet()
        _ = set.replace(set.slots[1].id, with: Files.file("given"))
        let places = ScreenshotHandPlace.kept(in: set)
        #expect(places.map(\.mcpID) == ["template:1", "file:given", "template:3", "template:4", "template:5"])
        #expect(places.map(\.madeBy) == ["template", "file", "template", "template", "template"])
        let live = ScreenshotHandPlace(position: 0, base: .live(id: "s1", fileName: "1.png", checksum: nil), fileID: nil, fileName: nil)
        #expect(live.mcpID == "live:s1")
        #expect(live.madeBy == "live")
    }

    @Test func arrangingIgnoresAnOrderThatIsntTheKeptOnes() {
        var set = Files.templateSet()
        let ids = set.kept.map(\.id)
        let partial = set.arrange(Array(ids.dropLast()))
        #expect(!partial)
        let reversed = set.arrange(Array(ids.reversed()))
        #expect(reversed)
        #expect(set.kept.map(\.id) == Array(ids.reversed()))
    }
}
#endif
