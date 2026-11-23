//
//  ProductPageTestModelProposalTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// “Test with Product Page Optimization…” opened on an assistant's
/// proposal: its name, traffic, languages and treatment filled in, the
/// person's Create Test making it (a library image without uploading
/// again), and the proposal recorded as made only once the test was.
@MainActor
@Suite("Product Page Optimization sheet from a proposal")
struct ProductPageTestModelProposalTests {
    private typealias Fixtures = ProductPageTestProposalFixtures
    private let folder = FileManager.default.temporaryDirectory.appending(path: "PPOProposal-\(UUID().uuidString)")

    private func makeModel(
        _ proposal: ProductPageTestProposal, variant: ExtrasArtworkVariant? = ExtrasReviewFixtures.variant(),
        environment: ProductPageTestEnvironment? = nil
    ) throws -> ProductPageTestModel {
        var extras = Fixtures.extras(variant: variant)
        extras.receive(proposal)
        var withVariant = extras
        withVariant.variant = ExtrasReviewFixtures.variant()
        try ExtrasReviewFixtures.writeFiles(of: withVariant, into: folder)
        let planner = ExtrasReviewPlanner { [folder] id, pathExtension in folder.appending(path: "\(id).\(pathExtension)") }
        let plan = try #require(ExtrasReviewFixtures.plan(extras, planner: planner))
        #expect(plan.testProposals == [proposal])
        return ProductPageTestModel(
            plan: plan, placement: proposal.placement, environment: environment,
            fileURL: { [folder] id, pathExtension in folder.appending(path: "\(id).\(pathExtension)") },
            exportFolder: folder.appending(path: "Export"), loadExtras: { nil }, proposal: proposal
        )
    }

    @Test func itOpensFilledInWithTheProposal() throws {
        var proposal = Fixtures.proposal(locales: ["en-US", "fr-FR"])
        proposal.startsTest = true
        let model = try makeModel(proposal)
        #expect(model.phase == .variantReady)
        #expect(model.testName == "Header: Editor vs Calm morning")
        #expect(model.trafficProportion == 30)
        #expect(model.startsTest, "The proposal's choice to start with")
        #expect(model.rows.map(\.locale) == ["en-US", "fr-FR"], "Only the proposal's languages")
        let request = try #require(model.request)
        #expect(request.testName == "Header: Editor vs Calm morning")
        #expect(request.trafficProportion == 30)
        #expect(request.startsTest)
        #expect(request.locales.map(\.locale) == ["en-US", "fr-FR"])
    }

    @Test func aLibraryTreatmentNeedsNoVariant() throws {
        let assets = [
            ProductPageTestLibraryAsset(locale: "en-US", assetID: "lib-en", name: "Morning · en-US", pixelSize: Fixtures.headerSize),
            ProductPageTestLibraryAsset(locale: "de-DE", assetID: "lib-de", name: "Morning · de-DE", pixelSize: Fixtures.headerSize),
        ]
        let proposal = Fixtures.proposal(treatment: .library(assets), locales: ["en-US", "de-DE"])
        let model = try makeModel(proposal, variant: nil, environment: ProductPageTestFixtures.environment(FakeProductPageTesting()))
        #expect(model.usesLibrary)
        #expect(model.phase == .variantReady)
        #expect(model.treatmentName == "Library image")
        #expect(model.rows.map(\.libraryName) == ["Morning · en-US", "Morning · de-DE"])
        #expect(model.rows.allSatisfy { $0.treatment == nil })
        #expect(model.canCreateTest)
        let request = try #require(model.request)
        #expect(request.locales.map(\.libraryAsset) == [
            AssetLibraryAsset(id: "lib-en", media: .image), AssetLibraryAsset(id: "lib-de", media: .image),
        ])
        #expect(request.locales.allSatisfy { $0.treatmentFile == nil })
        #expect(request.locales.first?.controlFile?.lastPathComponent == "header-en-US-sum.png")
    }

    @Test func makingTheTestRecordsTheProposalAsMade() async throws {
        let tester = FakeProductPageTesting()
        let model = try makeModel(Fixtures.proposal(), environment: ProductPageTestFixtures.environment(tester))
        var made: [(String, String)] = []
        model.onProposalMade = { id, outcome in made.append((id, outcome)) }
        model.createTest()
        await model.run?.waitUntilFinished()
        #expect(model.phase == .finished)
        #expect(tester.log.contains("create Header: Editor vs Calm morning 30"))
        #expect(made.map(\.0) == ["pt-1"])
        #expect(made.first?.1.contains("draft") == true)
    }

    @Test func aTestThatWasntMadeLeavesTheProposalOpen() async throws {
        let tester = FakeProductPageTesting(.init(tests: [Fixtures.running]))
        let model = try makeModel(Fixtures.proposal(), environment: ProductPageTestFixtures.environment(tester))
        var made: [String] = []
        model.onProposalMade = { id, _ in made.append(id) }
        model.createTest()
        await model.run?.waitUntilFinished()
        #expect(made.isEmpty)
    }

    @Test func aProposalThatAskedForTheVariantOpensWaitingForIt() throws {
        let center = AutopilotTestFixtures.center()
        let appID = StudioDebugRuns.appID
        center.install(StudioDebugExtras.run(.ready))
        #expect(center.requestVariant(appID: appID, role: .header, kind: .header))
        let model = try makeModel(Fixtures.proposal(treatment: .variant(change: "")), variant: nil)
        #expect(model.phase == .intro)
        model.adoptRequest(of: center.run(for: appID))
        #expect(model.phase == .asking)
        #expect(model.createBlockReason == "The variant isn’t in yet.")
    }
}
#endif
