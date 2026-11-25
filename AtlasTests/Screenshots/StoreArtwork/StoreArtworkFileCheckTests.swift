//
//  StoreArtworkFileCheckTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Which files Add… and Replace… take.
@Suite("Store artwork file check")
struct StoreArtworkFileCheckTests {
    @Test func aHeaderIsExactly3840By1646() {
        #expect(StoreArtworkFileCheck.accepts(PixelSize(width: 3840, height: 1646), place: .header))
        #expect(!StoreArtworkFileCheck.accepts(PixelSize(width: 1920, height: 823), place: .header))
        #expect(!StoreArtworkFileCheck.accepts(PixelSize(width: 3840, height: 2160), place: .header))
    }

    @Test func searchIsThreeByTwoFrom1200To3840Wide() {
        #expect(StoreArtworkFileCheck.accepts(PixelSize(width: 3840, height: 2560), place: .search))
        #expect(StoreArtworkFileCheck.accepts(PixelSize(width: 1200, height: 800), place: .search))
        #expect(StoreArtworkFileCheck.accepts(PixelSize(width: 1921, height: 1280), place: .search), "Within a pixel")
        #expect(!StoreArtworkFileCheck.accepts(PixelSize(width: 900, height: 600), place: .search))
        #expect(!StoreArtworkFileCheck.accepts(PixelSize(width: 4800, height: 3200), place: .search))
        #expect(!StoreArtworkFileCheck.accepts(PixelSize(width: 3840, height: 2160), place: .search))
    }

    @Test func eachProblemSaysTheFix() {
        #expect(StoreArtworkFileCheck.fits.problem(fileName: "a.png", place: .header) == nil)
        let header = StoreArtworkFileCheck.wrongSize(PixelSize(width: 1920, height: 823)).problem(fileName: "a.png", place: .header)
        #expect(header?.hasSuffix("Use 3840 × 1646.") == true)
        let search = StoreArtworkFileCheck.wrongSize(PixelSize(width: 900, height: 600)).problem(fileName: "a.png", place: .search)
        #expect(search?.hasSuffix("Use 3:2, up to 3840 × 2560.") == true)
        #expect(StoreArtworkFileCheck.unreadable.problem(fileName: "a.txt", place: .search)?.contains("“a.txt”") == true)
        #expect(StoreArtworkFileCheck.transparent.problem(fileName: "a.png", place: .search)?.contains("transparency") == true)
    }

    @Test func aFileThatIsntAnImageIsUnreadable() {
        let file = ScreenshotHandChosenFile(fileName: "notes.txt", data: Data("hello".utf8))
        #expect(StoreArtworkFileCheck(file, place: .header) == .unreadable)
    }
}
#endif
