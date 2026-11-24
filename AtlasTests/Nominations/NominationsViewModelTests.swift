//
//  NominationsViewModelTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The Nominations section on Lumen, Nov 24, 2026: the gallery's groups,
/// Add to Review & Push, Submit only after its confirmation, Archive,
/// Delete Draft, the line under each card, and the errors.
@MainActor
@Suite("Nominations · view model")
struct NominationsViewModelTests {
    typealias Data = DebugNominationsData

    private let queue = ChangeQueue()
    private let store = NominationsStore()

    private func model(
        _ services: DebugNominationsServices = DebugNominationsServices(), archive: NominationsArchive = Data.archive()
    ) async -> NominationsViewModel {
        store.load(archive, for: Data.lumen)
        let model = NominationsViewModel(app: DebugFixtures.lumen, services: services, store: store, queue: queue)
        model.now = { Data.now }
        _ = await model.load()
        return model
    }

    private var rows: [String] {
        queue.changes(for: Data.lumen, section: .nominations).map(\.id).sorted()
    }

    @Test func theGalleryGroupsDraftsSubmittedAndArchived() async {
        let model = await model()
        #expect(model.nominations(in: .draft).map(\.id) == [Data.draftID])
        #expect(model.nominations(in: .submitted).map(\.id) == [Data.winterID])
        #expect(model.nominations(in: .archived).map(\.id) == [Data.japanID])
        #expect(!model.isEmpty)
        #expect(model.problem == nil)
    }

    @Test func addToReviewPushQueuesTheCreateAndNothingElse() async {
        let model = await model()
        #expect(model.canAddToReviewPush(Data.draft))
        #expect(model.addToReviewPush(Data.draftID))
        #expect(rows == ["nomination.create.\(Data.draftID)"])
        #expect(model.toast?.text == "In Review & Push. Nothing is sent until you push.")
        #expect(!model.canAddToReviewPush(Data.draft))
        model.undo()
        #expect(rows.isEmpty)
    }

    @Test func aDraftWithProblemsIsNotAdded() async throws {
        let model = await model()
        model.update(Data.draftID) { $0.publishStart = Data.day(2026, 11, 20) }
        #expect(!model.addToReviewPush(Data.draftID))
        #expect(rows.isEmpty)
        #expect(try model.blockingReason(#require(model.nomination(Data.draftID))) == "The start date has passed. Pick one that hasn’t.")
    }

    @Test func submitIsQueuedOnlyAfterItsConfirmation() async throws {
        let model = await model()
        model.sheet = .submit(Data.draftID)
        #expect(rows.isEmpty)
        model.confirmSubmit(Data.draftID)
        #expect(model.sheet == nil)
        #expect(rows == ["nomination.create.\(Data.draftID)", "nomination.submit.\(Data.draftID)"])
        #expect(try model.need(#require(model.nomination(Data.draftID))).text == "Submit waits in Review & Push")
        // Cancel Submit keeps the draft's Create.
        model.removeFromReviewPush(Data.draftID, kinds: [.submit])
        #expect(rows == ["nomination.create.\(Data.draftID)"])
    }

    @Test func archiveIsForASubmittedNomination() async {
        let model = await model()
        model.confirmArchive(Data.draftID)
        #expect(rows.isEmpty)
        model.confirmArchive(Data.winterID)
        #expect(rows == ["nomination.archive.\(Data.winterID)"])
        #expect(model.need(Data.winter).text == "Archive waits in Review & Push")
    }

    @Test func aSubmittedNominationCantBeChanged() async {
        let model = await model()
        model.update(Data.winterID) { $0.name = "Changed" }
        #expect(model.nomination(Data.winterID)?.content.name == Data.winter.content.name)
        #expect(!model.isEdited(Data.winter))
    }

    @Test func editingAnAppStoreConnectDraftQueuesAnUpdate() async throws {
        var draft = Data.winter
        draft.state = .draft
        let model = await model(DebugNominationsServices(nominations: [draft]))
        model.update(Data.winterID) { $0.notes = "Changed notes." }
        #expect(try model.isEdited(#require(model.nomination(Data.winterID))))
        #expect(model.addToReviewPush(Data.winterID))
        #expect(rows == ["nomination.update.\(Data.winterID)"])
        // Back to what App Store Connect has: nothing left to update.
        model.update(Data.winterID) { $0.notes = Data.winter.content.notes }
        #expect(try !model.isEdited(#require(model.nomination(Data.winterID))))
    }

    @Test func deletingALocalDraftCanBeUndone() async {
        let model = await model()
        model.deleteDraft(Data.draftID)
        #expect(model.nomination(Data.draftID) == nil)
        model.undo()
        #expect(model.nomination(Data.draftID) != nil)
    }

    @Test func deletingAnAppStoreConnectDraftIsARow() async {
        var draft = Data.winter
        draft.state = .draft
        let model = await model(DebugNominationsServices(nominations: [draft]))
        model.deleteDraft(Data.winterID)
        #expect(rows == ["nomination.delete.\(Data.winterID)"])
    }

    @Test func anUntouchedNewDraftGoesAwayOnBack() async {
        let model = await model()
        model.newNomination()
        #expect(model.nominations(in: .draft).count == 2)
        model.back()
        #expect(model.nominations(in: .draft).map(\.id) == [Data.draftID])
    }

    @Test func theLineUnderEachCard() async {
        let model = await model()
        #expect(model.need(Data.draft).text == "Start date in 9 days: Apple suggests a few weeks ahead")
        #expect(model.need(Data.draft).tone == .warning)
        var later = Data.draft
        later.content.publishStart = Data.day(2027, 2, 2)
        #expect(model.need(later).text == "Ready to add to Review & Push")
        #expect(model.need(Data.winter).text == "Nothing needs you · Apple doesn’t report back")
        #expect(model.need(NominationsViewModelTests.empty).text == "Add a type, a name, a description, and a start date")
    }

    private static var empty: Nomination {
        Nomination.newDraft(appID: Data.lumen, now: Data.now)
    }

    @Test func aRoleThatCantWriteBlocksEveryWrite() async {
        let model = await model(DebugNominationsServices(error: AppStoreConnectError.forbidden(detail: "No.")))
        #expect(model.problem == .keyRole)
        #expect(model.keyCannotWrite)
        #expect(!model.addToReviewPush(Data.draftID))
        #expect(model.nominations(in: .draft).map(\.id) == [Data.draftID])
    }

    @Test func offlineKeepsTheDraftsOnThisMac() async {
        let model = await model(DebugNominationsServices(error: URLError(.notConnectedToInternet)))
        #expect(model.problem == .offline)
        #expect(model.nominations.map(\.id) == [Data.draftID])
    }

    @Test func atlasSuggestsTheTypeAndDescription() async throws {
        var archive = Data.archive()
        archive.drafts[0].content.type = nil
        archive.drafts[0].content.description = ""
        let model = await model(archive: archive)
        let draft = try #require(model.nomination(Data.draftID))
        let type = model.builtInSuggestion(.type, for: draft)
        #expect(type?.type == .newContent)
        #expect(type?.why == "Winter Journaling Week is new content for people who already have the app.")
        let description = model.builtInSuggestion(.description, for: draft)
        #expect(description?.text.hasPrefix("Weekly reflections: each Sunday") == true)
        #expect(description?.why.hasPrefix("Written from 1.4’s What’s New") == true)
        if let type { model.acceptBuiltIn(type) }
        #expect(model.nomination(Data.draftID)?.content.type == .newContent)
        #expect(rows.isEmpty)
    }

    @Test func knownLinksLeaveOutWhatMaterialsHave() async {
        let model = await model()
        let links = model.knownLinks(for: Data.draft).map(\.url)
        #expect(!links.contains(Data.appStorePage))
        var bare = Data.draft
        bare.content.materials = []
        #expect(model.knownLinks(for: bare).map(\.url).contains(Data.appStorePage))
    }

    @Test func acceptingAnAssistantsNominationQueuesItsCreateAsTheirs() async {
        let model = await model(archive: Data.archive(proposal: true))
        #expect(model.newProposals.map(\.id) == [Data.proposalID])
        model.acceptProposal(Data.proposalID)
        #expect(model.newProposals.isEmpty)
        let accepted = model.nominations(in: .draft).first { $0.suggestedBy == Data.client }
        #expect(accepted != nil)
        let create = queue.changes(for: Data.lumen, section: .nominations).first
        #expect(create?.source == .assistant(client: Data.client))
        #expect(create?.id.hasPrefix("nomination.create.") == true)
        #expect(!rows.contains { $0.hasPrefix("nomination.submit.") })
    }

    @Test func movingALinkOutOfTheDescription() async throws {
        let model = await model()
        model.update(Data.draftID) { $0.description += " Watch: https://lumen.app/weekly" }
        model.moveLinksToMaterials(Data.draftID)
        let content = try #require(model.nomination(Data.draftID)?.content)
        #expect(NominationLink.links(in: content.description).isEmpty)
        #expect(content.materials.contains("https://lumen.app/weekly"))
    }
}
