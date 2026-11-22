//
//  ProductPageChosenFilesTests.swift
//  AtlasTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Atlas

/// Choose Files…: screenshots the person has become a page's own set in
/// one language, checked against the sizes App Store Connect takes.
@MainActor
@Suite("Custom Product Pages · Choose Files")
struct ProductPageChosenFilesTests {
    typealias Sample = DebugProductPagesData
    typealias PageID = DebugProductPagesData.PageID

    private func file(_ name: String, _ width: Int, _ height: Int) -> ProductPageChosenFile {
        ProductPageChosenFile(fileName: name, data: Data(name.utf8), pixelSize: PixelSize(width: width, height: height))
    }

    private var folder: ProductPageFilesFolder {
        ProductPageFilesFolder(root: FileManager.default.temporaryDirectory.appending(path: "AtlasPageFilesTests-\(UUID().uuidString)"))
    }

    // MARK: - The check

    @Test func appleSizesAreTakenEitherWayRound() {
        #expect(ProductPageFileCheck.problems([file("a.png", 1320, 2868), file("b.png", 2796, 1290)], device: .iPhone).isEmpty)
        #expect(ProductPageFileCheck.problems([file("c.png", 2732, 2048)], device: .iPad).isEmpty)
    }

    @Test func eachWrongFileIsSaidWithTheSizesThatWork() {
        let problems = ProductPageFileCheck.problems(
            [file("small.png", 1170, 2532), ProductPageChosenFile(fileName: "notes.txt", data: Data(), pixelSize: nil)], device: .iPhone
        )
        #expect(problems == [
            "“small.png” is 1170 × 2532. iPhone 6.9″ takes 1320 × 2868, 1290 × 2796 or 1260 × 2736, upright or turned.",
            "“notes.txt” isn’t a PNG or JPEG image Atlas can read.",
        ])
        #expect(ProductPageFileCheck.problems([file("ipad-on-iphone.png", 2064, 2752)], device: .iPhone).count == 1)
    }

    @Test func aSetHasUpToTenScreenshots() {
        let eleven = (1...11).map { file("\($0).png", 1320, 2868) }
        #expect(ProductPageFileCheck.problems(eleven, device: .iPhone) == [
            "A set has up to 10 screenshots, and 11 were chosen. Choose 10 or fewer.",
        ])
    }

    @Test func aPNGsSizeIsReadFromItsHeader() throws {
        let context = try #require(CGContext(
            data: nil, width: 6, height: 13, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        let image = try #require(context.makeImage())
        let data = try #require(ScreenshotPNG.data(image))
        #expect(ProductPagesViewModel.pixelSize(of: data) == PixelSize(width: 6, height: 13))
        #expect(ProductPagesViewModel.pixelSize(of: Data("not an image".utf8)) == nil)
    }

    // MARK: - In the editor

    @Test func chosenScreenshotsWaitInReviewAndPushInPlaceOfEarlierOnes() async throws {
        let queue = ChangeQueue()
        let model = await ProductPagesTestModel.make(queue: queue)
        let page = try ProductPagesTestModel.page(model, PageID.mood)
        let folder = folder
        model.addChosenFiles([file("1.png", 1320, 2868), file("2.png", 1320, 2868)], for: page, locale: "en-US", folder: folder)
        let first = try #require(model.queuedScreenshots(of: page, locale: "en-US", device: .iPhone)?.first?.path)
        model.addChosenFiles([file("3.png", 1290, 2796)], for: page, locale: "en-US", folder: folder)
        // The set it replaced is gone from this Mac.
        #expect(!FileManager.default.fileExists(atPath: first))

        let changes = queue.changes(for: model.app.id, section: .productPages)
        #expect(changes.count == 1)
        let files = try #require(model.queuedScreenshots(of: page, locale: "en-US", device: .iPhone))
        #expect(files.map(\.fileName) == ["3.png"])
        #expect(FileManager.default.fileExists(atPath: files[0].path))
        #expect(files[0].checksum == ScreenshotPNG.checksum(Data("3.png".utf8)))
        #expect(model.toast?.text == "1 screenshot added to “\(page.name)” in \(ProductPageChangeBuilder.localeName("en-US")). It’s waiting in Review & Push, top right.")
        #expect(model.filesProblem == nil)
    }

    @Test func aDiscardedSetsFilesAreDeletedAtTheNextRead() async throws {
        let queue = ChangeQueue()
        let model = await ProductPagesTestModel.make(queue: queue)
        let page = try ProductPagesTestModel.page(model, PageID.mood)
        let folder = folder
        model.addChosenFiles([file("1.png", 1320, 2868)], for: page, locale: "en-US", folder: folder)
        let path = try #require(model.queuedScreenshots(of: page, locale: "en-US", device: .iPhone)?.first?.path)
        queue.discard(ids: queue.changes.map(\.id))
        model.pruneChosenFiles(folder: folder)
        #expect(!FileManager.default.fileExists(atPath: path))
    }

    @Test func wrongFilesAreRefusedWithEveryReasonAndNothingIsQueued() async throws {
        let queue = ChangeQueue()
        let model = await ProductPagesTestModel.make(queue: queue)
        let page = try ProductPagesTestModel.page(model, PageID.mood)
        model.device = .iPad
        model.addChosenFiles([file("phone.png", 1320, 2868)], for: page, locale: "en-US", folder: folder)
        #expect(queue.changes.isEmpty)
        let problem = try #require(model.filesProblem)
        #expect(problem.problems.count == 1)
        #expect(problem.title == "These screenshots can’t go to “\(page.name)”")
    }

    @Test func aPageWithAppReviewTakesNoFiles() async throws {
        let services = FakeProductPagesServices()
        services.pushPrivateDiary(.waitingForReview)
        let queue = ChangeQueue()
        let model = await ProductPagesTestModel.make(services, queue: queue)
        let page = try ProductPagesTestModel.page(model, PageID.privateDiaryPushed)
        #expect(!model.canChooseFiles(for: page))
        model.addChosenFiles([file("1.png", 1320, 2868)], for: page, locale: "en-US", folder: folder)
        #expect(queue.changes.isEmpty)
    }
}
