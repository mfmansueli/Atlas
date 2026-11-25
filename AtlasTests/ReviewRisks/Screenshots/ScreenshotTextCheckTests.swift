//
//  ScreenshotTextCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `ScreenshotTextCheck` on hand-built facts: what the text in the live
/// screenshots breaks, per screenshot, and sets that don't show the app
/// in use.
@Suite("App Review risks · text in screenshots")
struct ScreenshotTextCheckTests {
    private func facts(_ screenshots: [ReviewRiskScreenshot]?, appName: String = "Lumen") -> ReviewRiskFacts {
        var facts = ReviewRiskFacts(appID: "app1", appName: appName)
        facts.screenshots = screenshots.map { ReviewRiskScreenshotFacts(screenshots: $0) }
        return facts
    }

    private func shot(
        _ lines: [String], slot: Int = 1, locale: String = "en-US", display: ScreenshotDisplayType = .iPhone, checksum: String? = nil
    ) -> ReviewRiskScreenshot {
        ReviewRiskScreenshot(locale: locale, displayType: display, slot: slot, checksum: checksum ?? "sum\(locale)\(slot)", lines: lines)
    }

    private func risks(_ facts: ReviewRiskFacts) -> [ReviewRisk] {
        guard case let .risks(risks) = ScreenshotTextCheck().run(facts) else { return [] }
        return risks
    }

    // MARK: - Not checked

    @Test func withoutScreenshotsItSaysWhy() {
        guard case .notChecked = ScreenshotTextCheck().run(facts(nil)) else {
            Issue.record("expected notChecked")
            return
        }
        guard case .notChecked = ScreenshotTextCheck().run(facts([])) else {
            Issue.record("expected notChecked without screenshots")
            return
        }
        let unread = ReviewRiskScreenshot(locale: "en-US", displayType: .iPhone, slot: 1, wasRead: false)
        guard case .notChecked = ScreenshotTextCheck().run(facts([unread])) else {
            Issue.record("expected notChecked when nothing could be read")
            return
        }
    }

    @Test func aCleanSetIsClear() {
        let found = risks(facts([shot(["Write every day", "Your journal"], slot: 1), shot(["Look back on your week"], slot: 2)]))
        #expect(found.isEmpty)
    }

    // MARK: - Text

    @Test func freeIsLikelyWithThePlaceAndTheWords() throws {
        let found = risks(facts([shot(["Write every day"], slot: 1), shot(["Your journal", "FREE"], slot: 3)]))
        let risk = try #require(found.first)
        #expect(found.count == 1)
        #expect(risk.level == .likely)
        #expect(risk.guideline == "2.3.7")
        #expect(risk.howSure == .fairlySure)
        #expect(risk.title.contains("FREE"))
        #expect(risk.title.split(separator: " ").count <= 8)
        #expect(risk.why.count <= 110)
        #expect(risk.evidence.first?.place.contains("screenshot 3") == true)
        #expect(risk.evidence.first?.place.contains("English (U.S.)") == true)
        #expect(risk.evidence.first?.excerpt == "FREE")
        #expect(risk.evidence.first?.locale == "en-US")
        #expect(risk.fix.tool == "propose_screenshot_file")
        #expect(risk.fix.arguments == ["locale": "en-US", "displayType": "iphone", "position": "3"])
        #expect(risk.id.hasPrefix("screenshotText:APP_IPHONE_67.en-US.3.free"))
    }

    @Test func anAmountIsOnlyWorthALook() throws {
        let risk = try #require(risks(facts([shot(["Groceries", "$4.99"])])).first)
        #expect(risk.level == .check)
        #expect(risk.howSure == .notVerySure)
        #expect(risk.guideline == "2.3.7")
    }

    @Test func otherPlatformsAndApplesRecognitionsAreLikely() {
        let found = risks(facts([shot(["Also on Google Play"], slot: 1), shot(["Editor’s Choice"], slot: 2)]))
        #expect(Set(found.map(\.guideline)) == ["2.3.10", "5.2.5"])
        #expect(found.allSatisfy { $0.level == .likely })
    }

    @Test func theSameImageInTwoLanguagesIsOneRisk() throws {
        let english = shot(["FREE"], slot: 2, locale: "en-US", checksum: "same")
        let german = shot(["FREE"], slot: 2, locale: "de-DE", checksum: "same")
        let found = risks(facts([english, german]))
        let risk = try #require(found.first)
        #expect(found.count == 1)
        #expect(risk.evidence.map(\.locale) == ["en-US", "de-DE"])
    }

    @Test func idsAreStableAcrossRuns() {
        let input = facts([shot(["FREE", "$4.99"], slot: 2)])
        #expect(risks(input).map(\.id) == risks(input).map(\.id))
        #expect(Set(risks(input).map(\.id)).count == 2)
    }

    @Test func ordinaryWordsAndTheAppsNameAreNotRisks() {
        let found = risks(facts(
            [shot(["Freedom to write", "Ad-free journaling", "Feel free to skip a day"]), shot(["Free Notes"], slot: 2)],
            appName: "Free Notes"
        ))
        #expect(found.isEmpty)
    }

    // MARK: - The app in use

    @Test func aSetOfSignInScreensIsWorthALook() throws {
        let signIn = ["Sign In"]
        let screenshots = [
            ReviewRiskScreenshot(locale: "en-US", displayType: .iPhone, slot: 1, lines: ["Sign In", "Password"], signInLines: signIn),
            ReviewRiskScreenshot(locale: "en-US", displayType: .iPhone, slot: 2, lines: [], isMostlyBlank: true),
            ReviewRiskScreenshot(locale: "en-US", displayType: .iPhone, slot: 3, lines: ["Your week"]),
        ]
        let risk = try #require(risks(facts(screenshots)).first { $0.guideline == "2.3.3" })
        #expect(risk.level == .check)
        #expect(risk.id == "screenshotText:APP_IPHONE_67.en-US.appInUse")
        #expect(risk.evidence.count == 2)
        #expect(risk.why.hasPrefix("iPhone: 2 of 3"))
        #expect(risk.why.count <= 110)
        #expect(risk.fix.arguments["displayType"] == "iphone")
    }

    @Test func aFewSignInOrAlertScreensAmongMoreAreFine() {
        var screenshots = (1...4).map { ReviewRiskScreenshot(locale: "en-US", displayType: .iPhone, slot: $0, lines: ["Your week"]) }
        screenshots[0].signInLines = ["Sign In"]
        screenshots[1].systemAlertLine = "“Lumen” Would Like to Send You Notifications"
        #expect(risks(facts(screenshots)).isEmpty)
    }
}
