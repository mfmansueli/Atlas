//
//  ScreenshotFolderImporterTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Import a Folder: fastlane's layout and Atlas's export, read into one
/// row per language and device, with what's skipped and why.
@Suite("ScreenshotFolderImporter")
struct ScreenshotFolderImporterTests {
    private typealias Files = ScreenshotHandTestFiles
    private typealias Found = ScreenshotFolderImporter.Found

    private let importer = ScreenshotFolderImporter(
        pageLocales: [.englishUS, .german, StoreLocaleCatalog.locale(code: "ja")!, StoreLocaleCatalog.locale(code: "it")!],
        appName: "Lumen Journal"
    )

    private func found(_ path: String, size: PixelSize = PixelSize(width: 1320, height: 2868)) -> Found {
        let parts = path.split(separator: "/").map(String.init)
        return Found(path: parts, file: Files.chosen(parts.last ?? path, size: size))
    }

    @Test func fastlanesLayoutGivesARowPerLanguageAndDevice() throws {
        let rows = importer.rows(for: [
            found("de-DE/iphone-6.9/02.png"), found("de-DE/iphone-6.9/01.png"),
            found("ja/iphone-6.9/01.png"),
            found("de-DE/ipad-13/01.png", size: PixelSize(width: 2064, height: 2752)),
        ])
        #expect(rows.count == 3)
        let german = try #require(rows.first { $0.localeCode == "de-DE" && $0.displayType == .iPhone })
        #expect(german.isReady)
        #expect(german.files.map(\.fileName) == ["01.png", "02.png"])
        #expect(rows.contains { $0.localeCode == "de-DE" && $0.displayType == .iPad && $0.isReady })
    }

    @Test func theDeviceComesFromThePixelSizeWithoutAName() throws {
        let rows = importer.rows(for: [found("ja/01.png", size: PixelSize(width: 2048, height: 2732))])
        #expect(try #require(rows.first).displayType == .iPad)
    }

    @Test func aLanguageNotOnThePageIsSkippedWithTheReason() throws {
        let row = try #require(importer.rows(for: [found("pt-PT/iphone-6.9/01.png")]).first)
        #expect(!row.isReady)
        #expect(row.problem == "Skipped: Portuguese (Portugal) isn’t on Lumen Journal’s App Store page. Add it in Store Page first.")
    }

    @Test func wrongSizesAreSkippedNeverScaled() throws {
        let row = try #require(importer.rows(for: [found("it/iphone-6.9/01.png", size: PixelSize(width: 1179, height: 2556))]).first)
        #expect(!row.isReady)
        #expect(row.problem == "Skipped: 1179 × 2556 isn’t an iPhone 6.9″ size.")
    }

    @Test func moreThanTenKeepsTheFirstTen() throws {
        let row = try #require(importer.rows(for: (1...12).map { found(String(format: "ja/iphone-6.9/%02d.png", $0)) }).first)
        #expect(row.files.count == 10)
        #expect(row.skippedFiles.count == 2)
    }

    @Test func fastlanesDeviceNamesAreRead() {
        #expect(ScreenshotFolderImporter.device(in: ["0_APP_IPHONE_67_0.png"]) == .iPhone)
        #expect(ScreenshotFolderImporter.device(in: ["iPad Pro (13-inch)-01.png"]) == .iPad)
        #expect(ScreenshotFolderImporter.device(in: ["mac"]) == .mac)
        #expect(ScreenshotFolderImporter.device(in: ["01.png"]) == nil)
    }

    @Test func theLeadingNumberOrdersTheFiles() {
        let names = ["10.png", "2.png", "01.png"].sorted { ScreenshotFolderImporter.orderKey($0) < ScreenshotFolderImporter.orderKey($1) }
        #expect(names == ["01.png", "2.png", "10.png"])
    }

    @Test func aRealFolderIsRead() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "hand-import-\(UUID().uuidString)")
        let folder = root.appending(path: "de-DE/iphone-6.9")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Files.chosen("01.png").data.write(to: folder.appending(path: "01.png"))
        try Data("x".utf8).write(to: folder.appending(path: "notes.txt"))
        let rows = importer.rows(in: root)
        #expect(rows.count == 1)
        #expect(rows.first?.localeCode == "de-DE")
        #expect(rows.first?.files.count == 1)
    }
}
#endif
