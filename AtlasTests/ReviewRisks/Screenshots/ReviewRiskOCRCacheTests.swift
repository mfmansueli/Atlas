//
//  ReviewRiskOCRCacheTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Readings kept by checksum and language, so a refresh doesn't read the
/// same image twice; nothing kept without a folder.
@Suite("App Review risks · screenshot reading cache")
struct ReviewRiskOCRCacheTests {
    private let reading = ReviewRiskScreenshotReading(lines: [ReviewRiskScreenshotLine(text: "FREE", top: 0.2)], blankShare: 0.31)

    @Test func aReadingIsKeptByChecksumAndLanguage() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ReviewRiskOCRCacheTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ReviewRiskOCRCache(directory: directory)
        let key = try #require(ReviewRiskOCRCache.key(checksum: "abc123", screenshotID: "s1", locale: "de-DE"))
        #expect(cache.reading(for: key) == nil)
        cache.keep(reading, for: key)
        #expect(cache.reading(for: key) == reading)
        let english = try #require(ReviewRiskOCRCache.key(checksum: "abc123", screenshotID: "s1", locale: "en-US"))
        #expect(english != key)
        #expect(cache.reading(for: english) == nil)
    }

    @Test func keysAreFileNames() {
        #expect(ReviewRiskOCRCache.key(checksum: "abc", screenshotID: "s1", locale: "de-DE") == "abc-de-DE-v\(ReviewRiskOCRCache.version)")
        #expect(ReviewRiskOCRCache.key(checksum: nil, screenshotID: "a/b", locale: "ja")?.contains("/") == false)
        #expect(ReviewRiskOCRCache.key(checksum: "", screenshotID: "", locale: "ja") == nil)
    }

    @Test func withoutAFolderNothingIsKept() {
        let cache = ReviewRiskOCRCache(directory: nil)
        cache.keep(reading, for: "k")
        #expect(cache.reading(for: "k") == nil)
        #expect(ReviewRiskOCRCache.shared.directory == nil)
    }
}
