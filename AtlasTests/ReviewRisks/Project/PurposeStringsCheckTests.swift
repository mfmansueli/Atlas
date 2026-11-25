//
//  PurposeStringsCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `PurposeStringsCheck` (5.1.1(ii), ITMS-90683): permission texts that are
/// missing, vague, or left untranslated.
@Suite("Review risks · permission texts")
struct PurposeStringsCheckTests {
    private typealias Fixtures = ReviewRiskProjectFixtures
    private let check = PurposeStringsCheck()

    private func risks(_ outcome: ReviewRiskOutcome) -> [ReviewRisk] {
        if case let .risks(risks) = outcome { return risks }
        return []
    }

    private func project(_ texts: [String: String], uses: [ReviewRiskPermission] = []) -> ReviewRiskProjectFacts {
        var project = Fixtures.project()
        for (key, value) in texts {
            project.purposeStrings[key] = ReviewRiskPurposeString(key: key, value: value, place: "Lumen/Info.plist:12")
        }
        for permission in uses {
            project.add(Fixtures.match("API", file: "Lumen/Scanner/CameraView.swift", line: 42), for: .permission(permission))
        }
        return project
    }

    @Test func withoutAProjectFolderItIsNotChecked() {
        #expect(check.run(Fixtures.facts(nil)) == .notChecked(ReviewRiskProjectCheckSupport.noProject))
    }

    @Test func aCameraInUseWithoutItsTextBlocksReview() throws {
        let project = Fixtures.scanned("""
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        """, file: "Lumen/Scanner/CameraView.swift")
        let risk = try #require(risks(check.run(Fixtures.facts(project))).first)
        #expect(risk.id == "purposeStrings:missing.NSCameraUsageDescription")
        #expect(risk.level == .blocksReview)
        #expect(risk.evidence.map(\.place) == ["Info.plist · NSCameraUsageDescription", "Lumen/Scanner/CameraView.swift:1"])
        #expect(risk.fix.advice.contains("NSCameraUsageDescription"))
        #expect(risk.why.count <= AssistantTextLimits.why)
        #expect(AssistantTextLimits.titleRefusal(risk.title, field: "title") == nil)
    }

    @Test func anEmptyTextCountsAsMissingAndOnlyOnce() {
        let found = risks(check.run(Fixtures.facts(project(["NSCameraUsageDescription": " "], uses: [.camera]))))
        #expect(found.map(\.id) == ["purposeStrings:missing.NSCameraUsageDescription"])
    }

    @Test func aClearTextForEveryUseIsClear() {
        let texts = ["NSCameraUsageDescription": "Scans receipts so you can file expenses."]
        #expect(check.run(Fixtures.facts(project(texts, uses: [.camera]))) == .clear)
    }

    @Test func faceIDWithoutItsTextIsLikely() throws {
        let risk = try #require(risks(check.run(Fixtures.facts(project([:], uses: [.faceID])))).first)
        #expect(risk.level == .likely)
    }

    @Test func savingPhotosIsCoveredByFullPhotosAccess() {
        let texts = ["NSPhotoLibraryUsageDescription": "Adds the photos you pick to your journal entries."]
        #expect(check.run(Fixtures.facts(project(texts, uses: [.photosAdd]))) == .clear)
    }

    @Test func aShortOrStockTextIsVague() throws {
        let risk = try #require(risks(check.run(Fixtures.facts(project(["NSCameraUsageDescription": "Camera access"])))).first)
        #expect(risk.id == "purposeStrings:vague.NSCameraUsageDescription")
        #expect(risk.level == .likely)
        #expect(risk.evidence.first?.excerpt == "Camera access")
        #expect(risk.why.count <= AssistantTextLimits.why)
    }

    @Test func whatCountsAsVague() {
        let key = "NSCameraUsageDescription"
        #expect(PurposeStringsCheck.isVague("", key: key))
        #expect(PurposeStringsCheck.isVague(key, key: key))
        #expect(PurposeStringsCheck.isVague("We need access", key: key))
        #expect(PurposeStringsCheck.isVague("This app needs access to your camera.", key: key))
        #expect(PurposeStringsCheck.isVague("$(PRODUCT_NAME) requires access to the photo library", key: key))
        #expect(PurposeStringsCheck.isVague("需要相机", key: key))
        #expect(!PurposeStringsCheck.isVague("We need access to your camera to scan receipts.", key: key))
        #expect(!PurposeStringsCheck.isVague("Scans receipts so you can file expenses.", key: key))
        #expect(!PurposeStringsCheck.isVague("用于扫描收据和发票以便报销。", key: key))
    }

    @Test func aTextLeftInEnglishWhereTheAppAndStoreSpeakFrenchNeedsALook() throws {
        var project = project(["NSCameraUsageDescription": "Scans receipts so you can file expenses."], uses: [.camera])
        project.purposeStrings["NSCameraUsageDescription"]?.languages = ["de"]
        project.languages = ["en", "de", "fr"]
        let facts = Fixtures.facts(project, texts: Fixtures.texts(["en-US", "de-DE", "fr-FR"]))
        let risk = try #require(risks(check.run(facts)).first)
        #expect(risk.id == "purposeStrings:translations")
        #expect(risk.level == .check)
        #expect(risk.evidence.count == 1)
        #expect(risk.why.count <= AssistantTextLimits.why)
    }

    @Test func languagesOnlyTheStoreSpeaksAreNotAsked() {
        var project = project(["NSCameraUsageDescription": "Scans receipts so you can file expenses."], uses: [.camera])
        project.languages = ["en"]
        let storeOnly = Fixtures.facts(project, texts: Fixtures.texts(["en-US", "ja"]))
        #expect(check.run(storeOnly) == .clear)
        let english = Fixtures.facts(project, texts: Fixtures.texts(["en-US", "en-GB"]))
        #expect(check.run(english) == .clear)
        let noTexts = Fixtures.facts(project, texts: nil)
        #expect(check.run(noTexts) == .clear)
    }
}
