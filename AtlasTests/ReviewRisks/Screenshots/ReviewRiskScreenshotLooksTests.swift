//
//  ReviewRiskScreenshotLooksTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Whether a screenshot shows an iOS permission alert, a sign-in screen
/// or a mostly blank screen, from the lines read in it; captions that
/// mention those things don't count.
@Suite("App Review risks · how a screenshot looks")
struct ReviewRiskScreenshotLooksTests {
    private typealias Looks = ReviewRiskScreenshotLooks

    @Test func aPermissionAlertWithTheAppsNameInQuotes() {
        let lines = ["“Lumen” Would Like to Send You Notifications", "Notifications may include alerts and sounds.", "Don’t Allow", "Allow"]
        #expect(Looks.systemAlertLine(in: lines, appName: "Lumen Journal") == lines[0])
    }

    @Test func aButtonOnlySystemAlertsHave() {
        #expect(Looks.systemAlertLine(in: ["Your week", "Allow While Using App"], appName: "Lumen") == "Allow While Using App")
    }

    @Test func captionsAboutPermissionsAreNotAlerts() {
        #expect(Looks.systemAlertLine(in: ["Allow notifications to stay on track", "Your week"], appName: "Lumen") == nil)
        #expect(Looks.systemAlertLine(in: ["“Lumen” keeps you calm", "Breathe"], appName: "Lumen") == nil)
    }

    @Test func aSignInScreen() {
        let lines = ["Welcome back", "Email", "Password", "Sign In", "Forgot password?"]
        #expect(Set(Looks.signInLines(in: lines)) == ["Email", "Password", "Sign In", "Forgot password?"])
        #expect(!Looks.signInLines(in: ["Continue with Apple", "Continue with Google"]).isEmpty)
    }

    @Test func captionsAboutSigningInAndBusyScreensAreNot() {
        #expect(Looks.signInLines(in: ["Sign in with Apple in one tap", "Your journal"]).isEmpty)
        #expect(Looks.signInLines(in: ["Password"]).isEmpty)
        let busy = ["Sign In", "Password"] + (1...14).map { "Entry \($0)" }
        #expect(Looks.signInLines(in: busy).isEmpty)
    }

    @Test func mostlyBlankOnlyWithLittleTextOnPhonesAndTablets() {
        let blank = ReviewRiskScreenshotReading(lines: [ReviewRiskScreenshotLine(text: "Today", top: 0.1)], blankShare: 0.82)
        #expect(Looks.isMostlyBlank(blank, on: .iPhone))
        #expect(Looks.isMostlyBlank(blank, on: .iPad))
        #expect(!Looks.isMostlyBlank(blank, on: .watch))
        #expect(!Looks.isMostlyBlank(blank, on: .mac))
        let busy = ReviewRiskScreenshotReading(lines: (1...8).map { ReviewRiskScreenshotLine(text: "Row \($0)", top: 0.1) }, blankShare: 0.82)
        #expect(!Looks.isMostlyBlank(busy, on: .iPhone))
        #expect(!Looks.isMostlyBlank(ReviewRiskScreenshotReading(blankShare: 0.3), on: .iPhone))
        #expect(!Looks.isMostlyBlank(ReviewRiskScreenshotReading(blankShare: nil), on: .iPhone))
    }
}
