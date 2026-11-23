//
//  ScreenshotsHandArrangementViewModelTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// An assistant's removal or new order on the Japanese and English sample
/// sets: accepted, it changes only that language's set and waits in
/// Review & Push; dismissed, nothing changes; the primary language keeps
/// one.
@MainActor
@Suite("Screenshots by hand: suggested removals and orders")
struct ScreenshotsHandArrangementViewModelTests {
    private func model(_ locale: String = "ja") async -> (ScreenshotsViewModel, FakeScreenshotsServices) {
        let (model, services) = await ScreenshotsTestFixtures.viewModel()
        model.pageLocale = StoreLocaleCatalog.locale(code: locale)
        model.displayType = .iPhone
        return (model, services)
    }

    /// Puts an arrangement naming `positions` (from 0) of the set as it starts.
    private func suggest(
        _ action: ScreenshotHandArrangement.Action,
        _ positions: [Int],
        locale: String = "ja",
        in model: ScreenshotsViewModel
    ) async throws -> ScreenshotHandArrangement {
        var document = try #require(model.document)
        let set = document.handSetOrStart(locale: locale, displayType: .iPhone, live: model.live)
        let places = ScreenshotHandPlace.kept(in: set)
        document.handArrangements = [ScreenshotHandArrangement(
            id: "ha", client: "Claude Code", receivedAt: .now, locale: locale, displayType: .iPhone,
            action: action, places: positions.map { places[$0] }, reason: "Screens 2 and 4 show the same feature."
        )]
        await model.commit(document)
        return try #require(model.handArrangements(locale: locale, displayType: .iPhone).first)
    }

    @Test func acceptingARemovalDeletesThemInThatLanguageOnly() async throws {
        let (model, services) = await model()
        let removal = try await suggest(.removal, [1, 3], in: model)
        #expect(model.handArrangementTitle(removal) == "Delete screenshots 2 and 4")
        #expect(model.handArrangementCells(removal).allSatisfy { $0 != nil })
        await model.acceptHandArrangement(removal)
        let saved = try #require(services.storedDocument?.handSet(locale: "ja", displayType: .iPhone))
        #expect(saved.keptCount == 3)
        #expect(saved.slots.count(where: \.isDeleted) == 2)
        #expect(services.storedDocument?.handSets?.count == 1)
        #expect(services.storedDocument?.handArrangements?.first?.status == .accepted)
        #expect(model.handArrangements(locale: "ja", displayType: .iPhone).isEmpty)
        #expect(model.handRevision == 1)
        #expect(model.captionToast?.text == "Screenshots 2 and 4 will be deleted in Japanese when you push.")
        #expect(model.captionToast?.actionTitle == "Review & Push")
    }

    @Test func acceptingAnOrderMovesThem() async throws {
        let (model, services) = await model()
        let order = try await suggest(.order, [2, 0, 1, 3, 4], in: model)
        #expect(model.handArrangementTitle(order) == "New order: 3, 1, 2, 4, 5")
        await model.acceptHandArrangement(order)
        let saved = try #require(services.storedDocument?.handSet(locale: "ja", displayType: .iPhone))
        #expect(saved.kept.map { $0.base?.templateSlot } == [2, 0, 1, 3, 4])
        #expect(model.captionToast?.text == "Japanese’s screenshots are in Claude Code’s order. In Review & Push.")
    }

    @Test func undoPutsTheSetAndTheSuggestionBack() async throws {
        let (model, services) = await model()
        let removal = try await suggest(.removal, [0], in: model)
        await model.acceptHandArrangement(removal)
        await model.undoCaptionToast()
        #expect(services.storedDocument?.handSets == nil)
        #expect(model.handArrangements(locale: "ja", displayType: .iPhone).count == 1)
    }

    @Test func dismissingChangesNothing() async throws {
        let (model, services) = await model()
        let removal = try await suggest(.removal, [0], in: model)
        await model.dismissHandArrangement(removal)
        #expect(services.storedDocument?.handSets == nil)
        #expect(services.storedDocument?.handArrangements?.first?.status == .rejected)
        #expect(model.handArrangements(locale: "ja", displayType: .iPhone).isEmpty)
    }

    @Test func thePrimaryLanguageKeepsOne() async throws {
        let (model, services) = await model("en-US")
        let count = model.ownCount(locale: "en-US", displayType: .iPhone)
        let removal = try await suggest(.removal, Array(0..<count), locale: "en-US", in: model)
        await model.acceptHandArrangement(removal)
        #expect(services.storedDocument?.handSets == nil)
        #expect(model.notice?.contains("primary language") == true)
        #expect(model.handArrangements(locale: "en-US", displayType: .iPhone).count == 1)
    }
}
#endif
