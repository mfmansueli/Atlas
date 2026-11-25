//
//  ScreenshotExtrasStoreArtworkTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Add…, Replace…, Delete… and Undo Change on the set's extras, and what a
/// push notes.
@Suite("Screenshot extras: header and search by hand")
struct ScreenshotExtrasStoreArtworkTests {
    private typealias Fixtures = StoreArtworkFixtures

    @Test func aHandFileReplacesThePlacesFileAndWidensTheSize() {
        var extras = Fixtures.extras()
        #expect(extras.artworkSize == nil)
        extras.setHandArtwork(Fixtures.handFile(.header, fileID: "one"))
        #expect(extras.artworkSize == .headerOnly)
        extras.setHandArtwork(Fixtures.handFile(.header, fileID: "two"))
        #expect(extras.artwork.map(\.fileID) == ["two"])
        extras.setHandArtwork(Fixtures.handFile(.search, fileID: "three"))
        #expect(extras.artworkSize == .headerAndSearch)
    }

    @Test func aHandFileTakesBackADeletion() {
        var extras = Fixtures.extras()
        extras.markRemoval(.header, locale: "de-DE", at: Fixtures.date)
        extras.setHandArtwork(Fixtures.handFile(.header))
        #expect(extras.removal(.header, locale: "de-DE") == nil)
        #expect(extras.artworkRemovals == nil)
    }

    @Test func deleteMarksOnceAndDropsTheWaitingHandFile() {
        var extras = Fixtures.extras([Fixtures.handFile(.header)])
        extras.markRemoval(.header, locale: "de-DE", at: Fixtures.date)
        extras.markRemoval(.header, locale: "de-DE", at: Fixtures.date)
        #expect(extras.artworkRemovals?.count == 1)
        #expect(extras.artworkRemovals?.first?.id == "remove-header-de-DE")
        #expect(extras.pendingArtwork(.header, locale: "de-DE") == nil)
        #expect(extras.artwork.isEmpty)
    }

    @Test func undoOnAnAutopilotFileDiscardsItAndKeepsIt() {
        let made = Fixtures.madeFile(.search)
        var extras = Fixtures.extras()
        extras.artwork = [made]
        extras.undoArtworkChange(.search, locale: "de-DE")
        #expect(extras.artwork == [made], "It stays in the set")
        #expect(extras.discardedChecksums?[made.id] == made.fileID)
        #expect(extras.pendingArtwork(.search, locale: "de-DE") == nil)
    }

    @Test func undoTakesBackADeletion() {
        var extras = Fixtures.extras()
        extras.markRemoval(.search, locale: "ja", at: Fixtures.date)
        extras.undoArtworkChange(.search, locale: "ja")
        #expect(extras.removal(.search, locale: "ja") == nil)
    }

    @Test func aPushedDeletionLeavesAndAPushedFileIsNoted() {
        let file = Fixtures.handFile(.header)
        var extras = Fixtures.extras([file])
        extras.markRemoval(.search, locale: "ja", at: Fixtures.date)
        extras.notePushed("remove-search-ja", fileID: "remove-search-ja")
        #expect(extras.artworkRemovals == nil)
        #expect(extras.pushedChecksums?["remove-search-ja"] == nil)
        extras.notePushed(file.id, fileID: file.fileID)
        #expect(extras.pushedChecksums?[file.id] == file.fileID)
        #expect(!extras.waits(file))
    }

    @Test func aHandFileKnowsItsOwnSize() {
        var file = Fixtures.handFile(.search)
        file.byHand?.pixelSize = PixelSize(width: 1800, height: 1200)
        #expect(file.pixelSize == PixelSize(width: 1800, height: 1200))
        #expect(Fixtures.madeFile(.search).pixelSize == AutopilotArtworkKind.search.pixelSize)
    }

    @Test func removalsSurviveSavingTheDocument() throws {
        var extras = Fixtures.extras([Fixtures.handFile(.header)])
        extras.markRemoval(.search, locale: "ja", at: Fixtures.date)
        let decoded = try JSONDecoder().decode(ScreenshotExtras.self, from: JSONEncoder().encode(extras))
        #expect(decoded.artworkRemovals == extras.artworkRemovals)
        #expect(decoded.artwork.first?.byHand == extras.artwork.first?.byHand)
    }
}
#endif
