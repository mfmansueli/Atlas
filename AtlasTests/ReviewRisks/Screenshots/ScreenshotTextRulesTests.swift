//
//  ScreenshotTextRulesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What App Review rejects in the text read in a screenshot: “free” and
/// trials apart from offers and amounts, other platforms, Apple's
/// recognitions; ordinary words and the app's own name left alone.
@Suite("App Review risks · screenshot text rules")
struct ScreenshotTextRulesTests {
    private func kinds(_ lines: [String], appName: String = "") -> [ScreenshotTextFindingKind] {
        ScreenshotTextRules.findings(in: lines, appName: appName).map(\.kind)
    }

    @Test func freeInAnyCaseAndLanguageIsFree() {
        #expect(kinds(["Write every day", "FREE"]) == [.free])
        #expect(kinds(["Jetzt kostenlos"]) == [.free])
        #expect(kinds(["Try it with a 7-day trial"]) == [.free])
        let finding = ScreenshotTextRules.findings(in: ["FREE"]).first
        #expect(finding?.phrases == ["FREE"])
    }

    @Test func amountsAndOffersAreKeptApart() {
        #expect(kinds(["Lunch", "$4.99"]) == [.amount])
        #expect(kinds(["50% off this week"]) == [.offer])
        #expect(kinds(["Special offer"]) == [.offer])
        #expect(ScreenshotTextRules.isAmount("R$ 9,90"))
        #expect(!ScreenshotTextRules.isAmount("50% off"))
    }

    @Test func otherPlatformsAndApplesRecognitions() {
        #expect(kinds(["Also on Google Play"]) == [.otherPlatform])
        #expect(kinds(["Editor’s Choice"]) == [.appleRecognition])
        #expect(kinds(["App of the Day"]) == [.appleRecognition])
        #expect(kinds(["Lorem ipsum dolor"]) == [.placeholder])
    }

    @Test func ordinaryWordsAreNotFindings() {
        #expect(kinds(["Freedom to write", "Ad-free journaling", "Feel free to skip a day", "Hands-free notes"]).isEmpty)
        #expect(kinds(["Your best week yet", "Photos", "9:41"]).isEmpty)
        #expect(kinds([]).isEmpty)
    }

    @Test func theAppsOwnNameIsLeftOut() {
        #expect(kinds(["Free Notes", "Your ideas, sorted"], appName: "Free Notes").isEmpty)
        #expect(kinds(["FREE"], appName: "Lumen") == [.free])
    }
}
