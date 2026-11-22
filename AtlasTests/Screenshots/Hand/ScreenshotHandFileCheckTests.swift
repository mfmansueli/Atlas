//
//  ScreenshotHandFileCheckTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// A file given by hand is checked like App Store Connect would: one of
/// the device's sizes, upright or turned, no transparency, never scaled.
@Suite("ScreenshotHandFileCheck")
struct ScreenshotHandFileCheckTests {
    @Test func iPhoneTakesItsSizesUprightOrTurned() {
        #expect(ScreenshotHandSizes.accepts(PixelSize(width: 1320, height: 2868), on: .iPhone))
        #expect(ScreenshotHandSizes.accepts(PixelSize(width: 2796, height: 1290), on: .iPhone))
        #expect(!ScreenshotHandSizes.accepts(PixelSize(width: 1179, height: 2556), on: .iPhone))
        #expect(ScreenshotHandSizes.accepts(PixelSize(width: 1280, height: 800), on: .mac))
        #expect(ScreenshotHandSizes.main(on: .iPad) == "2064 × 2752")
        #expect(ScreenshotHandSizes.others(on: .iPad) == "2048 × 2732")
    }

    @Test func aFileThatFitsIsReady() {
        let check = ScreenshotHandFileCheck(ScreenshotHandTestFiles.chosen("01.png"), on: .iPhone)
        #expect(check == .fits)
        #expect(check.shortTitle == "Ready")
    }

    @Test func aWrongSizeSaysWhichSizesToUse() throws {
        let file = ScreenshotHandTestFiles.chosen("IMG.png", size: PixelSize(width: 1179, height: 2556))
        let check = ScreenshotHandFileCheck(file, on: .iPhone)
        #expect(check == .wrongSize(PixelSize(width: 1179, height: 2556)))
        let problem = try #require(check.problem(fileName: file.fileName, on: .iPhone))
        #expect(problem.contains("1179 × 2556"))
        #expect(problem.contains("1320 × 2868"))
    }

    @Test func somethingThatIsntAnImageIsUnreadable() {
        let file = ScreenshotHandChosenFile(fileName: "notes.png", data: Data("hello".utf8))
        #expect(ScreenshotHandFileCheck(file, on: .iPhone) == .unreadable)
    }
}
#endif
