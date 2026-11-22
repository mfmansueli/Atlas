//
//  ScreenshotHandMatrixTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The matrix with sets changed by hand: the kept places in order, the
/// language page's row with the ones that will be deleted, and live sets
/// Atlas doesn't render.
@MainActor
@Suite("Screenshot matrix by hand")
struct ScreenshotHandMatrixTests {
    private typealias Files = ScreenshotHandTestFiles

    /// Japanese is live as Atlas pushed it on Oct 12.
    private func document(_ change: (inout ScreenshotHandSet) -> Void) -> ScreenshotsDocument {
        var document = ScreenshotsDebugDocuments.standard
        var set = document.handSetOrStart(locale: "ja", displayType: .iPhone, live: ScreenshotsDebugDocuments.live)
        change(&set)
        document.setHandSet(set, locale: "ja", displayType: .iPhone)
        return document
    }

    @Test func aReplacedScreenshotShowsTheFile() {
        let matrix = ScreenshotsTestFixtures.matrix(document { $0.replace(position: 1, with: Files.file("a")) })
        let row = matrix.row(locale: "ja", displayType: .iPhone)
        #expect(row.count == 5)
        #expect(row[1].image.handFile?.id == "a")
        #expect(row[1].state == .handReplaced)
        #expect(row[0].state == .live)
        #expect(matrix.isHandRow(locale: "ja", displayType: .iPhone))
    }

    @Test func aDeletedLiveScreenshotStaysOnThePageOnly() {
        let matrix = ScreenshotsTestFixtures.matrix(document { $0.delete(position: 2) })
        #expect(matrix.row(locale: "ja", displayType: .iPhone).count == 4)
        let page = matrix.pageRow(locale: "ja", displayType: .iPhone)
        #expect(page.count == 5)
        #expect(page[2].state == .willBeDeleted)
        #expect(page[2].live != nil)
    }

    @Test func anAddedFileIsNew() {
        let matrix = ScreenshotsTestFixtures.matrix(document { $0.add([Files.file("b")]) })
        let row = matrix.row(locale: "ja", displayType: .iPhone)
        #expect(row.count == 6)
        #expect(row[5].state == .handNew)
    }

    @Test func aMovedRenderKeepsBeingLive() {
        let matrix = ScreenshotsTestFixtures.matrix(document { set in set.swap(set.slots[0].id, set.slots[1].id) })
        let row = matrix.row(locale: "ja", displayType: .iPhone)
        let plain = ScreenshotsTestFixtures.matrix(ScreenshotsDebugDocuments.standard).row(locale: "ja", displayType: .iPhone)
        #expect(row.allSatisfy { $0.state == .live })
        #expect(row[0].image == plain[1].image)
        #expect(row[1].image == plain[0].image)
    }

    @Test func otherRowsDontChange() {
        let matrix = ScreenshotsTestFixtures.matrix(document { $0.delete(position: 0) })
        #expect(matrix.row(locale: "ko", displayType: .iPhone).count == 5)
        #expect(!matrix.isHandRow(locale: "ko", displayType: .iPhone))
    }
}
#endif
