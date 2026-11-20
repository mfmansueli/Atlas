//
//  PageShotsTestFixtures.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Make Screenshots for This Page (board 52) on Lumen Journal's Private
/// diary: the sample Screenshots document (five screens, captured on
/// iPhone and iPad), the page's four languages and the plan Claude Code
/// would send (`PageShotsDebugData`).
@MainActor
enum PageShotsTestFixtures {
    static let app = DebugFixtures.lumen
    static let pageName = "Private diary"
    static let pageID = DebugProductPagesData.PageID.privateDiary
    static let languages = ["en-US", "de-DE", "ja", "ar-SA"]
    static let key = PageShotsRun.Key(appID: app.id, pageName: pageName)

    static func source() async throws -> PageShotsSource {
        try await PageShotsSource.load(app: app, services: DebugScreenshotsServices())
    }

    static func run(
        stage: PageShotsStage = .plan, plan: PageShotsPlan? = nil, locales: [String] = ["en-US"],
        displays: [ScreenshotDisplayType] = [.iPhone], claudeRunID: UUID? = nil
    ) -> PageShotsRun {
        PageShotsRun(
            id: "run-1", appID: app.id, pageID: pageID, pageName: pageName, note: "People who want a diary nobody else can read.",
            stage: stage, plan: plan, languages: languages, locales: locales, displays: displays, templateName: "Lumen",
            claudeRunID: claudeRunID, startedAt: .now, updatedAt: .now
        )
    }

    /// The sample plan: privacy first, captions in `locales` (English,
    /// German and Arabic have them), `count` screens.
    static func plan(
        locales captioned: [String] = ["en-US", "de-DE", "ar-SA"], count: Int = 5, suggested: [String] = ["en-US", "ar-SA"],
        madeAt: Date = .now
    ) -> PageShotsPlan {
        let order = Array(PageShotsDebugData.order.prefix(count))
        let screens = order.enumerated().map { place, slot in
            PageShotsScreen(slot: slot, captions: PageShotsDebugData.captions.filter { captioned.contains($0.key) }.mapValues { $0[place] })
        }
        return PageShotsPlan(
            angle: "Privacy first.", screens: screens, locales: suggested, reason: "The lock comes first.", source: "Claude Code",
            madeAt: madeAt
        )
    }

    /// One of propose_page_screenshots' screens: the default set's `number`
    /// (1-based) with headlines by language.
    static func screen(_ number: Int, _ headlines: [String: String]) -> JSONValue {
        ["screen": .int(number), "captions": .object(headlines.mapValues { ["headline": .string($0)] })]
    }

    static func session(_ id: UUID) -> ClaudeCodeRun {
        ClaudeCodeRun(
            id: id, appID: app.id, appName: app.name, purpose: .pageScreenshots(pageName: pageName), prompt: "", workingDirectory: "/tmp",
            startedAt: .now
        )
    }
}
