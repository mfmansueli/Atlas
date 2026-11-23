//
//  ScreenshotsHandViewModelTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The language page's changes by hand on Lumen Journal's sample: select,
/// move, replace, delete and add, here or in every language, with Undo;
/// and an assistant's file accepted.
@MainActor
@Suite("Screenshots by hand")
struct ScreenshotsHandViewModelTests {
    private typealias Files = ScreenshotHandTestFiles

    private func japanese() async -> (ScreenshotsViewModel, FakeScreenshotsServices) {
        let (model, services) = await ScreenshotsTestFixtures.viewModel()
        model.pageLocale = StoreLocaleCatalog.locale(code: "ja")
        model.displayType = .iPhone
        return (model, services)
    }

    private func items(_ model: ScreenshotsViewModel, _ locale: String = "ja") -> [ScreenshotHandPageItem] {
        model.handPageItems(locale: locale, displayType: .iPhone)
    }

    @Test func theDeviceLineSaysTheSizeAndHowMany() async {
        let (model, _) = await japanese()
        #expect(model.handDeviceLine(locale: "ja", displayType: .iPhone).hasPrefix("iPhone 6.9″ · 1320 × 2868 · 5 of 10."))
    }

    @Test func selectingShowsWhereItComesFrom() async throws {
        let (model, _) = await japanese()
        model.selectHand(items(model)[1])
        let selected = try #require(model.selectedHandItem)
        #expect(selected.position == 1)
        #expect(model.handOrigin(of: selected.cell) == "Made by Atlas from the template and its caption · live")
        model.selectHand(selected)
        #expect(model.handSelection == nil)
    }

    @Test func replacingOnlyHereChangesOneLanguage() async throws {
        let (model, services) = await japanese()
        await model.replaceHand(slotID: items(model)[1].id, with: Files.chosen("ja-02.png"), scope: .one)
        let saved = try #require(services.storedDocument?.handSet(locale: "ja", displayType: .iPhone))
        #expect(saved.kept[1].file?.fileName == "ja-02.png")
        #expect(services.storedDocument?.handSets?.count == 1)
        #expect(items(model)[1].cell.state == .handReplaced)
        #expect(model.handRevision == 1)
        #expect(model.captionToast?.text == "Replaced screenshot 2 in Japanese. In Review & Push.")
        #expect(model.captionToast?.actionTitle == "Review & Push")
    }

    @Test func replacingInEveryLanguageChangesEachWithItsOwn() async {
        let (model, services) = await japanese()
        let own = model.ownLocales(on: .iPhone).count
        await model.replaceHand(slotID: items(model)[0].id, with: Files.chosen("same.png"), scope: .every)
        #expect(services.storedDocument?.handSets?.count == own)
    }

    @Test func undoInTheToastPutsItBack() async {
        let (model, services) = await japanese()
        await model.replaceHand(slotID: items(model)[1].id, with: Files.chosen("ja-02.png"), scope: .one)
        await model.undoCaptionToast()
        #expect(services.storedDocument?.handSets == nil)
        #expect(model.handRevision == 2)
    }

    @Test func deletingMarksItUntilThePush() async {
        let (model, _) = await japanese()
        await model.deleteHand(slotID: items(model)[2].id, scope: .one)
        #expect(items(model).count == 5)
        #expect(items(model)[2].isDeleted)
        #expect(model.ownCount(locale: "ja", displayType: .iPhone) == 4)
        #expect(model.captionToast?.text == "Screenshot 3 will be deleted in Japanese when you push.")
    }

    @Test func thePrimaryLanguagesLastScreenshotCantGo() async throws {
        let (model, _) = await ScreenshotsTestFixtures.viewModel()
        model.pageLocale = .englishUS
        for _ in 0..<4 {
            let first = try #require(items(model, "en-US").first { !$0.isDeleted })
            await model.deleteHand(slotID: first.id, scope: .one)
        }
        let last = try #require(items(model, "en-US").first { !$0.isDeleted })
        #expect(!model.canDeleteHand(last))
        await model.deleteHand(slotID: last.id, scope: .one)
        #expect(model.ownCount(locale: "en-US", displayType: .iPhone) == 1)
    }

    @Test func addingSkipsWrongSizes() async {
        let (model, _) = await japanese()
        await model.addHand([Files.chosen("06.png"), Files.chosen("bad.png", size: PixelSize(width: 1179, height: 2556))], scope: .one)
        #expect(model.ownCount(locale: "ja", displayType: .iPhone) == 6)
        #expect(items(model).last?.cell.state == .handNew)
    }

    @Test func movingRightSwapsAndKeepsTheSelection() async throws {
        let (model, _) = await japanese()
        let first = items(model)[0]
        model.selectHand(first)
        await model.moveSelectedHand(by: 1)
        let moved = try #require(model.selectedHandItem)
        #expect(moved.position == 1)
        #expect(moved.cell.image == first.cell.image)
    }

    @Test func undoChangeBringsTheTemplateBack() async {
        let (model, services) = await japanese()
        await model.replaceHand(slotID: items(model)[1].id, with: Files.chosen("ja-02.png"), scope: .one)
        // Replacing keeps it selected (clicking it again would deselect it).
        #expect(model.handSelection?.slotID == items(model)[1].id)
        await model.undoSelectedHand()
        #expect(services.storedDocument?.handSets == nil)
        #expect(items(model)[1].cell.image.renderJob != nil)
    }

    @Test func deleteAllInALanguage() async {
        let (model, _) = await japanese()
        await model.deleteAllHand()
        #expect(model.ownCount(locale: "ja", displayType: .iPhone) == 0)
        #expect(model.captionToast?.text == "All iPhone 6.9″ screenshots in Japanese will be deleted when you push.")
    }

    @Test func importingAFolderReplacesALanguagesScreenshots() async {
        let (model, _) = await japanese()
        let row = ScreenshotFolderImportRow(
            folderName: "ja", localeCode: "ja", languageName: "Japanese", displayType: .iPhone,
            files: [Files.chosen("01.png"), Files.chosen("02.png")], skippedFiles: [], problem: nil
        )
        await model.importHandFolder([row], mode: .replace)
        #expect(model.ownCount(locale: "ja", displayType: .iPhone) == 2)
        #expect(items(model).count == 7)
        #expect(model.captionToast?.text == "Imported 2 screenshots into 1 language. In Review & Push.")
    }

    @Test func anAssistantsFileIsAcceptedIntoItsPlace() async throws {
        let (model, services) = await japanese()
        guard var document = model.document else { return }
        var file = Files.file("p1")
        file.proposedBy = "Claude Code"
        document.handProposals = [ScreenshotHandProposal(
            id: "hp", client: "Claude Code", receivedAt: .now, locale: "ja", displayType: .iPhone, position: 2, file: file, reason: "Darker."
        )]
        await model.commit(document)
        let proposal = try #require(model.handProposals(locale: "ja", displayType: .iPhone).first)
        await model.acceptHandProposal(proposal)
        #expect(model.handProposals(locale: "ja", displayType: .iPhone).isEmpty)
        #expect(services.storedDocument?.handSet(locale: "ja", displayType: .iPhone)?.kept[2].file?.id == "p1")
        #expect(services.storedDocument?.handProposals?.first?.status == .accepted)
    }
}
#endif
