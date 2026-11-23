//
//  ProductPageTestReadinessTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// What each placement can be tested with, the proposed tests kept in the
/// extras (a newer one from the same assistant replaces its open one), and
/// a draft's deletion as a change in Review & Push.
@MainActor
@Suite("Product Page Optimization readiness")
struct ProductPageTestReadinessTests {
    private typealias Fixtures = ProductPageTestProposalFixtures

    @Test func eachPlacementSaysItsArtworkAndVariant() throws {
        let all = ProductPageTestReadiness.all(extras: Fixtures.extras(), primary: "en-US")
        #expect(all.map(\.placement) == [.header, .searchResults])
        let header = try #require(all.first)
        #expect(header.kind == .header)
        #expect(header.controlLocales == ["en-US", "de-DE", "fr-FR"])
        #expect(header.waitingLocales == ["en-US", "de-DE", "fr-FR"])
        #expect(header.variantLocales == ["en-US", "de-DE", "fr-FR"])
        #expect(header.variantBlockReason == nil)
        let search = all[1]
        #expect(search.kind == .search)
        #expect(search.variant == nil, "The header's variant isn't the search image's")
        #expect(search.variantBlockReason == "There’s no search results variant yet.")
    }

    @Test func pushedArtworkNoLongerWaits() throws {
        var extras = Fixtures.extras()
        for file in extras.artwork where file.kind == .header && file.locale != "fr-FR" {
            extras.pushedChecksums = (extras.pushedChecksums ?? [:]).merging([file.id: file.fileID]) { $1 }
        }
        let header = ProductPageTestReadiness(extras: extras, placement: .header, primary: "en-US")
        #expect(header.waitingLocales == ["fr-FR"])
    }

    @Test func withoutArtworkThereIsNothingToVary() {
        let header = ProductPageTestReadiness(extras: nil, placement: .header, primary: "en-US")
        #expect(header.kind == nil)
        #expect(header.variantBlockReason?.contains("treatment: library") == true)
    }

    @Test func sizesComeFromAppleOrAutopilot() {
        let refData = AssetLibraryRefDataSample.refData
        #expect(ProductPageTestReadiness.takes(Fixtures.headerSize, for: .header, refData: refData))
        #expect(!ProductPageTestReadiness.takes(PixelSize(width: 2000, height: 1000), for: .header, refData: refData))
        #expect(ProductPageTestReadiness.sizesTitle(for: .header, refData: refData) == "3840 × 1646 or 5244 × 2950")
        #expect(ProductPageTestReadiness.takes(Fixtures.headerSize, for: .header, refData: nil))
    }

    // MARK: - Kept in the extras

    @Test func aNewerProposalReplacesTheSameAssistantsOpenOne() {
        var extras = Fixtures.extras()
        #expect(extras.receive(Fixtures.proposal(id: "pt-1")) == nil)
        #expect(extras.receive(Fixtures.proposal(id: "pt-other", client: "Codex")) == nil, "Another assistant's stays")
        #expect(extras.receive(Fixtures.proposal(id: "pt-search", placement: .searchResults)) == nil, "Another placement stays")
        #expect(extras.receive(Fixtures.proposal(id: "pt-2")) == "pt-1")
        #expect(extras.openTestProposals.map(\.id) == ["pt-other", "pt-search", "pt-2"])
    }

    @Test func aDecidedProposalLeavesTheOpenOnes() {
        var extras = Fixtures.extras()
        extras.receive(Fixtures.proposal(id: "pt-1"))
        let decided = extras.decideTestProposal(id: "pt-1", status: .made, outcome: "Test created as a draft", at: Fixtures.now)
        let again = extras.decideTestProposal(id: "pt-1", status: .dismissed, at: Fixtures.now)
        let missing = extras.decideTestProposal(id: "pt-none", status: .dismissed, at: Fixtures.now)
        #expect(decided)
        #expect(!again, "Only an open one is decided")
        #expect(!missing)
        #expect(extras.openTestProposals.isEmpty)
        let made = extras.testProposal(id: "pt-1")
        #expect(made?.status == .made)
        #expect(made?.outcome == "Test created as a draft")
        #expect(made?.decidedAt == Fixtures.now)
        // A new proposal for the placement isn't replacing a decided one.
        #expect(extras.receive(Fixtures.proposal(id: "pt-2")) == nil)
    }

    @Test func proposalsSurviveSaving() throws {
        var extras = Fixtures.extras()
        let library = ProductPageTestLibraryAsset(locale: "en-US", assetID: "lib-en", name: "Morning", pixelSize: Fixtures.headerSize)
        extras.receive(Fixtures.proposal(id: "pt-1", treatment: .library([library]), locales: ["en-US"]))
        let decoded = try JSONDecoder().decode(ScreenshotExtras.self, from: JSONEncoder().encode(extras))
        #expect(decoded.testProposals == extras.testProposals)
        #expect(decoded.testProposals?.first?.treatment.libraryAssets == [library])
    }

    @Test func extrasHoldingOnlyProposalsArePlanned() throws {
        var extras = ScreenshotExtras.holdingProposals(at: Fixtures.now)
        #expect(ExtrasReviewFixtures.plan(extras) == nil, "Nothing to show")
        extras.receive(Fixtures.proposal(id: "pt-1"))
        let plan = try #require(ExtrasReviewFixtures.plan(extras))
        #expect(plan.testProposals.map(\.id) == ["pt-1"])
        #expect(!plan.isEmpty)
        #expect(plan.artwork.isEmpty)
    }

    // MARK: - Deleting a draft

    @Test func deletingADraftIsAChangeThatChecksItsStillADraft() throws {
        let change = ProductPageTestDeletion.change(
            appID: "app-1", experiment: Fixtures.draft, source: .assistant(client: "Claude Code"), reason: "It blocks the header test."
        )
        #expect(change.id == "pagetest.delete.exp-draft")
        #expect(change.section == .screenshots)
        #expect(change.group == "Product Page Optimization · Icons")
        #expect(change.groupNote == "It blocks the header test.")
        #expect(change.title == "Delete the draft test")
        #expect(change.oldValue == "A draft in App Store Connect, 30% of visitors")
        #expect(change.newValue == "Deleted")
        let request = try #require(change.requests.first)
        #expect(request.method == .delete)
        #expect(request.path == "/v2/appStoreVersionExperiments/exp-draft")
        #expect(change.conflictCheck?.expected == "PREPARE_FOR_SUBMISSION")
        #expect(ProductPageTestDeletion.queuedExperimentIDs(in: [change]) == ["exp-draft"])
    }
}
#endif
