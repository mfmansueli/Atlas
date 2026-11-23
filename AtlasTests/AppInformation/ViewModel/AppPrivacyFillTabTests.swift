//
//  AppPrivacyFillTabTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Fill In App Store Connect in the canvas's structure: the steps show as
/// soon as the first question has a reviewed answer, with what's left in
/// the worksheet above them, and Mark as Published waits for the worksheet,
/// not for every tick.
@MainActor
@Suite("AppPrivacyViewModel · fill tab")
struct AppPrivacyFillTabTests {
    private typealias Support = PrivacyTestSupport
    private let app = StoreApp(id: DebugFixtures.AppID.lumen, name: "Lumen Journal", bundleID: "dev.example.lumen", sku: nil, primaryLocale: "en-US")

    private func model(_ worksheet: PrivacyWorksheet) -> AppPrivacyViewModel {
        let section = AppInformationViewModel(app: app, services: DebugAppInformationServices(privacy: worksheet), queue: ChangeQueue())
        section.privacy.copy = { _ in }
        section.privacy.now = { Support.date }
        return section.privacy
    }

    @Test func noStepsBeforeTheFirstQuestionHasAnAnswer() {
        var worksheet = PrivacyWorksheet()
        worksheet.start()
        #expect(!model(worksheet).showsSteps)
    }

    @Test func stepsShowWhileSuggestionsStillWait() {
        var worksheet = Support.answered([.crash: Support.collected()])
        worksheet.propose(Support.suggestion(Support.collected([.analytics])), for: .coarseLocation, at: Support.date)
        let privacy = model(worksheet)
        #expect(privacy.worksheet.blockedReason != nil)
        #expect(privacy.showsSteps)
        #expect(!privacy.canMarkPublished)
    }

    @Test func aDoneWorksheetCanBeMarkedWithoutEveryTick() {
        let privacy = model(DebugPrivacyWorksheets.done)
        #expect(!privacy.worksheet.allStepsChecked)
        #expect(privacy.showsSteps)
        #expect(privacy.canMarkPublished)
    }
}
#endif
