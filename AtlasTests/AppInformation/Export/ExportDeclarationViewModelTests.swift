//
//  ExportDeclarationViewModelTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// The Export Compliance page with an assistant's encryption declaration
/// waiting in Review & Push: answering exempt or rejecting the evidence
/// takes it back with the build's answer. And App Compliance never
/// discards Pricing's change that puts China mainland on sale.
@MainActor
@Suite("Export Compliance declaration in the view model")
struct ExportDeclarationViewModelTests {
    private let queue = ChangeQueue()
    private let app = StoreApp(id: DebugFixtures.AppID.lumen, name: "Lumen Journal", bundleID: "dev.example.lumen", sku: nil, primaryLocale: "en-US")

    private func loaded() async -> AppInformationViewModel {
        let viewModel = AppInformationViewModel(app: app, services: DebugAppInformationServices(), queue: queue)
        await viewModel.load()
        return viewModel
    }

    /// The assistant's answers: not exempt, with a new declaration.
    private func queueAssistantsDeclaration(in vm: AppInformationViewModel) throws {
        let export = try #require(vm.content?.export)
        let answers = ExportComplianceAnswers(answers: [
            .usesEncryption: true, .isExempt: false, .proprietary: false, .thirdParty: true, .availableInFrance: true,
        ])
        let source = ChangeSource.assistant(client: "Claude Code")
        let encryption = try #require(vm.builder.encryptionChange(export, to: answers, source: source))
        let plan = try #require(EncryptionDeclarationPlan.plan(for: answers, appDescription: "Sync uses libsodium.", declarations: []))
        queue.upsert(encryption)
        try queue.upsert(#require(vm.builder.declarationChange(plan, export: export, source: source, dependsOn: encryption.id)))
        vm.notes.exportAnswers = answers
    }

    @Test func answeringExemptDiscardsTheDeclaration() async throws {
        let vm = await loaded()
        try queueAssistantsDeclaration(in: vm)
        #expect(vm.queuedDeclaration != nil)
        vm.setExportAnswer(true, for: .isExempt)
        #expect(vm.queuedDeclaration == nil)
    }

    @Test func rejectingTheEvidenceDiscardsBoth() async throws {
        let vm = await loaded()
        try queueAssistantsDeclaration(in: vm)
        vm.rejectExportEvidence()
        #expect(queue.change(id: vm.builder.encryptionChangeID) == nil)
        #expect(vm.queuedDeclaration == nil)
    }

    @Test func answeringChinasDeclarationsKeepsPricingsChangeThatSellsThere() async {
        let vm = await loaded()
        let id = vm.builder.stopSellingChangeID(ComplianceRegion.chinaMainland)
        let request = AppInformationChangeBuilder.patch("territoryAvailabilities", id: "lumen-availability-CHN", attributes: ["available": .bool(true)])
        queue.upsert(PendingChange(
            id: id, appID: app.id, section: .subscriptionPricing, group: "Pricing · Availability", title: "Availability · China mainland",
            oldValue: "Not available", newValue: "Available", requests: [request]
        ))
        vm.chooseChina(.no, for: .securityAssessment)
        #expect(queue.change(id: id) != nil)
        #expect(vm.icpChoice != .stopSelling)
        #expect(!vm.hasPendingChanges(on: .appCompliance))
    }
}
#endif
