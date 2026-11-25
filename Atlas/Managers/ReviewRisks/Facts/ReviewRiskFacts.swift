//
//  ReviewRiskFacts.swift
//  Atlas
//

import Foundation

/// Everything the checks read about one app, gathered once by
/// `ReviewRiskFactsLoader` so every check is a plain function of it (and
/// a unit test only builds one of these). A part that couldn't be read is
/// nil; the checks that need it say so in `notChecked`.
struct ReviewRiskFacts: Sendable {
    var appID: String
    var appName: String
    var bundleID: String
    var now: Date
    /// The version the checks look at (the one being prepared, else the
    /// live one) and its What's New.
    var version: ReviewRiskVersionFacts?
    /// Store texts pushed and waiting, in every language and place.
    var texts: ReviewRiskTextFacts?
    /// The person's other apps' texts, for 4.3.
    var siblings: [ReviewRiskSiblingApp]?
    /// Subscriptions, in-app purchases and the license agreement.
    var products: ReviewRiskProductFacts?
    /// Privacy Policy, Support, Marketing and Terms URLs, and whether they open.
    var links: ReviewRiskLinkFacts?
    /// What the app's Xcode project shows; nil without a project folder.
    var project: ReviewRiskProjectFacts?
    /// Age rating, App Review information, categories and App Compliance.
    var content: ReviewRiskContentFacts?
    /// Text read in the live screenshots.
    var screenshots: ReviewRiskScreenshotFacts?
    /// Why a part couldn't be read, by the checks it stops.
    var readGaps: [ReviewRiskGap] = []

    init(appID: String, appName: String, bundleID: String = "", now: Date = .now) {
        self.appID = appID
        self.appName = appName
        self.bundleID = bundleID
        self.now = now
    }

    /// The reason a part is missing for `check`, from the loader, else
    /// `fallback`.
    func gap(for check: ReviewRiskCheckID, fallback: String) -> String {
        readGaps.first { $0.check == check }?.reason ?? fallback
    }
}
