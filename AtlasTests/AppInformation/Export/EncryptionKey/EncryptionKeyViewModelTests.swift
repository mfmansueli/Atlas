//
//  EncryptionKeyViewModelTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Export Compliance's view model on Lumen's sample: Add It to the
/// Project waits for Confirm of Claude Code's answers, and answers that
/// only come from the build read as exempt, marked as the build's.
@MainActor
@Suite("Encryption key on the Export Compliance page")
struct EncryptionKeyViewModelTests {
    private let app = StoreApp(id: DebugFixtures.AppID.lumen, name: "Lumen Journal", bundleID: "dev.example.lumen", sku: nil, primaryLocale: "en-US")

    private func loaded(_ services: DebugAppInformationServices = DebugAppInformationServices()) async -> AppInformationViewModel {
        let viewModel = AppInformationViewModel(app: app, services: services, queue: ChangeQueue())
        await viewModel.load()
        return viewModel
    }

    @Test func confirmingTheAssistantsAnswersTurnsAddItOn() async throws {
        let vm = await loaded()
        #expect(vm.encryptionKeyReadiness?.reason == .unconfirmedSuggestion(client: "Claude Code"))
        let blocked = try #require(vm.encryptionKeyCard(report: nil, project: .noFolder, builds: [], answeredInAtlas: [], isRunning: false))
        #expect(blocked.readiness.answer == nil)
        #expect(blocked.disabledReason != nil)

        vm.confirmExportEvidence()
        let ready = try #require(vm.encryptionKeyCard(report: nil, project: .noFolder, builds: [], answeredInAtlas: [], isRunning: true))
        #expect(ready.readiness.answer?.value == .no)
        #expect(ready.readiness.answer?.basis == .confirmed)
        #expect(ready.isRunning)
        #expect(!vm.exportAnswersAreFromBuild)
    }

    @Test func answersOnlyFromTheBuildReadAsExemptAndAreMarked() async throws {
        let services = DebugAppInformationServices()
        services.notes.setNotes(AppInformationNotes(), for: app.id)
        let vm = await loaded(services)
        #expect(vm.exportAnswersAreFromBuild)
        let answers = try #require(vm.exportAnswers)
        #expect(answers[.usesEncryption] == true)
        #expect(answers[.isExempt] == true)
        #expect(answers.visibleQuestions == [.usesEncryption, .isExempt])
        #expect(vm.encryptionKeyReadiness?.answer?.basis == .build(number: "42"))
        // Answering it yourself keeps the build's flag: no change to push.
        vm.setExportAnswer(false, for: .usesEncryption)
        #expect(!vm.exportAnswersAreFromBuild)
        #expect(vm.exportAnswers?.usesNonExemptEncryption == false)
        #expect(vm.queue.change(id: vm.builder.encryptionChangeID) == nil)
    }

    @Test func theScenesAreListed() {
        for id in ["info-key-ready", "info-key-running", "info-key-added", "info-key-failed", "info-key-inferred", "info-export-first"] {
            #expect(AppInformationDebugScenes.ids.contains(id), "\(id)")
        }
        #expect(AppInformationDebugScenes.firstVersion.version?.state == .prepareForSubmission)
        #expect(AppInformationDebugScenes.report(.couldNotAdd).reason != nil)
    }
}
#endif
