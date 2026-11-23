//
//  ProductPageTestProposerTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// An assistant's proposed test, checked like “Test with Product Page
/// Optimization…” checks one: one test at a time, a variant without
/// Apple's errors, languages the treatment has, and library images that
/// are processed and of a size Apple takes. Each refusal says how to fix
/// it.
@MainActor
@Suite("Product Page Optimization proposals")
struct ProductPageTestProposerTests {
    private typealias Fixtures = ProductPageTestProposalFixtures

    private func refusal(_ outcome: ProductPageTestProposer.Outcome) -> (code: String, reason: String)? {
        guard case let .refused(code, reason) = outcome else { return nil }
        return (code, reason)
    }

    private func queued(_ outcome: ProductPageTestProposer.Outcome) -> (ProductPageTestProposal, Bool, [String])? {
        guard case let .queued(proposal, asks, notes) = outcome else { return nil }
        return (proposal, asks, notes)
    }

    // MARK: - The variant

    @Test func theVariantIsProposedInEveryLanguageItHas() throws {
        let (proposal, asks, notes) = try #require(queued(Fixtures.proposer().propose(Fixtures.input())))
        #expect(!asks)
        #expect(proposal.id.hasPrefix("pt-"))
        #expect(proposal.name == "Header: Interface vs Outcome")
        #expect(proposal.placement == .header)
        #expect(proposal.trafficProportion == 50, "Half the visitors by default")
        #expect(proposal.treatment == .variant(change: "A calm morning page instead of the editor"))
        #expect(proposal.locales == ["en-US", "de-DE", "fr-FR"])
        #expect(!proposal.startsTest)
        #expect(proposal.client == "Claude Code")
        #expect(proposal.receivedAt == Fixtures.now)
        #expect(proposal.status == .pending)
        #expect(proposal.evidence == ["analytics: page views to downloads 2.1%"])
        #expect(proposal.summary == "Header · 50% of visitors · 3 languages")
        // Autopilot's current header hasn't been pushed yet.
        #expect(notes.first?.contains("still waits in Review & Push in 3 languages") == true)
    }

    @Test func itKeepsTheNameTrafficAndLanguagesSent() throws {
        let input = Fixtures.input(traffic: 25, locales: ["de-DE", "en-US"], name: "  Calm header  ")
        let (proposal, _, _) = try #require(queued(Fixtures.proposer().propose(input)))
        #expect(proposal.name == "Calm header")
        #expect(proposal.trafficProportion == 25)
        #expect(proposal.locales == ["en-US", "de-DE"], "In the treatment's order, primary first")
    }

    @Test func aLanguageTheVariantLacksIsRefused() throws {
        let refused = try #require(refusal(Fixtures.proposer().propose(Fixtures.input(locales: ["ja"]))))
        #expect(refused.code == "unknown_locale")
        #expect(refused.reason.contains("no ja"))
        #expect(refused.reason.contains("en-US, de-DE, and fr-FR"))
    }

    @Test func aVariantWithAppleErrorsIsRefused() throws {
        let award = ArtworkCheck(kind: .appleRecognition, text: "German header: ‘Editor’s Choice’ isn’t allowed.")
        let proposer = Fixtures.proposer(extras: Fixtures.extras(variant: ExtrasReviewFixtures.variant(germanChecks: [award])))
        let refused = try #require(refusal(proposer.propose(Fixtures.input())))
        #expect(refused.code == "variant_breaks_rules")
        #expect(refused.reason.contains("Editor’s Choice"))
        #expect(refused.reason.contains("propose_artwork_variant"))
    }

    @Test func withoutAVariantItAsksTheRunOrSaysThereIsNone() throws {
        let asking = Fixtures.proposer(extras: Fixtures.extras(variant: nil), canAskForVariant: true)
        let (proposal, asks, _) = try #require(queued(asking.propose(Fixtures.input())))
        #expect(asks)
        #expect(proposal.treatment == .variant(change: ""))
        #expect(proposal.locales == ["en-US", "de-DE", "fr-FR"], "Every language the current header has")

        let refused = try #require(refusal(Fixtures.proposer(extras: Fixtures.extras(variant: nil)).propose(Fixtures.input())))
        #expect(refused.code == "no_variant")
        #expect(refused.reason.contains("no finished Autopilot run"))
    }

    @Test func noArtworkMeansNoVariantToTest() throws {
        let refused = try #require(refusal(Fixtures.proposer(extras: nil).propose(Fixtures.input())))
        #expect(refused.code == "no_artwork")
        #expect(refused.reason.contains("treatment: library"))
    }

    // MARK: - One test at a time

    @Test func aTestThatIsntOverRefusesANewOne() throws {
        let running = try #require(refusal(Fixtures.proposer(tests: [Fixtures.running]).propose(Fixtures.input())))
        #expect(running.code == "test_in_progress")
        #expect(running.reason.contains("“Screens” is running"))
        #expect(running.reason.contains("the API can’t stop one"))

        let draft = try #require(refusal(Fixtures.proposer(tests: [Fixtures.draft]).propose(Fixtures.input())))
        #expect(draft.code == "test_in_progress")
        #expect(draft.reason.contains("action: deleteDraft, testId: exp-draft"))
    }

    @Test func aDraftWhoseDeletionWaitsLetsItThrough() throws {
        let proposer = Fixtures.proposer(tests: [Fixtures.draft, Fixtures.over], queuedDeletions: ["exp-draft"])
        let (_, _, notes) = try #require(queued(proposer.propose(Fixtures.input())))
        #expect(notes.first == "Deleting the draft “Icons” waits in Review & Push: the person pushes that first.")
        #expect(proposer.blockingTest?.id == "exp-draft")
    }

    @Test func anotherPlatformsTestIsntInTheWay() throws {
        let mac = ProductPageExperiment(id: "exp-mac", name: "Mac", platform: "MAC_OS", state: "APPROVED")
        #expect(Fixtures.proposer(tests: [mac]).blockingTest == nil)
    }

    // MARK: - Library images

    @Test func libraryImagesAreProposedOnePerLanguage() throws {
        let input = Fixtures.input(treatment: "library", assets: ["de-DE": "lib-de", "en-US": "lib-en"])
        let (proposal, asks, _) = try #require(queued(Fixtures.proposer(extras: nil).propose(input)))
        #expect(!asks)
        #expect(proposal.name == "Header: Interface vs Library image")
        #expect(proposal.locales == ["en-US", "de-DE"])
        #expect(proposal.treatment.libraryAssets == [
            ProductPageTestLibraryAsset(locale: "en-US", assetID: "lib-en", name: "Morning · en-US · Header", pixelSize: Fixtures.headerSize),
            ProductPageTestLibraryAsset(locale: "de-DE", assetID: "lib-de", name: "Morning · de-DE · Header", pixelSize: Fixtures.headerSize),
        ])
        #expect(proposal.treatment.toolValue == "library")
    }

    @Test(arguments: [
        ("lib-none", "unknown_asset"), ("lib-video", "not_an_image"), ("lib-busy", "asset_not_ready"), ("lib-small", "wrong_size"),
    ])
    func aLibraryImageThatCantGoOnATestIsRefused(assetID: String, code: String) throws {
        let input = Fixtures.input(treatment: "library", assets: ["en-US": assetID])
        let refused = try #require(refusal(Fixtures.proposer().propose(input)))
        #expect(refused.code == code)
        if code == "wrong_size" {
            #expect(refused.reason.contains("2000 × 1000"))
            #expect(refused.reason.contains("3840 × 1646 or 5244 × 2950"))
        }
    }

    @Test func libraryProposalsNeedAssetsForTheirLanguagesAndALibrary() throws {
        let none = try #require(refusal(Fixtures.proposer().propose(Fixtures.input(treatment: "library"))))
        #expect(none.code == "no_assets")
        let mismatch = Fixtures.input(treatment: "library", assets: ["en-US": "lib-en"], locales: ["en-US", "de-DE"])
        #expect(refusal(Fixtures.proposer().propose(mismatch))?.code == "locales_mismatch")
        let unread = Fixtures.input(treatment: "library", assets: ["en-US": "lib-en"])
        #expect(refusal(Fixtures.proposer(library: nil).propose(unread))?.code == "library_unreadable")
    }

    @Test func libraryCandidatesAreProcessedImagesOfTheRightSize() {
        let header = ProductPageTestProposer.libraryCandidates(Fixtures.library, placement: .header, refData: AssetLibraryRefDataSample.refData)
        #expect(header.map(\.id) == ["lib-en", "lib-de"])
        // Without Apple's list, Autopilot's sizes.
        let fallback = ProductPageTestProposer.libraryCandidates(Fixtures.library, placement: .header, refData: nil)
        #expect(fallback.map(\.id) == ["lib-en", "lib-de"])
    }

    // MARK: - What's sent

    @Test func reasonTrafficAndTreatmentAreChecked() throws {
        #expect(refusal(Fixtures.proposer().propose(Fixtures.input(reason: "  ")))?.code == "no_reason")
        #expect(refusal(Fixtures.proposer().propose(Fixtures.input(reason: String(repeating: "a", count: 301))))?.code == "too_long")
        #expect(refusal(Fixtures.proposer().propose(Fixtures.input(name: String(repeating: "a", count: 65))))?.code == "too_long")
        #expect(refusal(Fixtures.proposer().propose(Fixtures.input(traffic: 0)))?.code == "traffic_out_of_range")
        #expect(refusal(Fixtures.proposer().propose(Fixtures.input(traffic: 101)))?.code == "traffic_out_of_range")
        #expect(refusal(Fixtures.proposer().propose(Fixtures.input(treatment: "icon")))?.code == "unknown_treatment")
    }
}
#endif
