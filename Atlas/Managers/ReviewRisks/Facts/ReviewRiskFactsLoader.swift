//
//  ReviewRiskFactsLoader.swift
//  Atlas
//

import Foundation

/// Gathers `ReviewRiskFacts` for one app from App Store Connect (through
/// the workspace's services), Review & Push, the project folder and the
/// person's other apps. Each part is read by its own extension
/// (`ReviewRiskFactsLoader+Texts.swift` and the rest), so a part that
/// fails leaves the others standing.
@MainActor
struct ReviewRiskFactsLoader {
    var services: WorkspaceServices
    var changes: ChangeQueue
    /// Every app in the account, for 4.3 and the app's own name.
    var apps: @MainActor () async throws -> [StoreApp]
    /// Reads the app's project folder; nil without a launcher (tests).
    var launcher: ClaudeCodeLauncher?
    /// Checks whether URLs open; tests pass a canned one.
    var urlProbe: any ReviewRiskURLProbing = LiveReviewRiskURLProbe()
    var now: @MainActor () -> Date = { .now }

    func facts(for app: StoreApp) async -> ReviewRiskFacts {
        var facts = ReviewRiskFacts(appID: app.id, appName: app.name, bundleID: app.bundleID, now: now())
        let shared = await ReviewRiskSharedContent.load(app, services: services)
        facts.version = await versionFacts(for: app, shared: shared)
        facts.texts = await textFacts(for: app, shared: shared)
        facts.siblings = await siblingApps(for: app)
        facts.products = await productFacts(for: app, shared: shared)
        facts.links = await linkFacts(for: app, shared: shared)
        facts.project = await projectFacts(for: app)
        facts.content = await contentFacts(for: app, shared: shared)
        facts.screenshots = await screenshotFacts(for: app, shared: shared)
        facts.readGaps = Self.gaps(from: shared)
        return facts
    }

    /// The checks a part that couldn't be read stops, with Apple's reason.
    nonisolated static func gaps(from shared: ReviewRiskSharedContent) -> [ReviewRiskGap] {
        let stops: [String: [ReviewRiskCheckID]] = [
            "storePage": [
                .storeTexts, .whatsNew, .subscriptionTerms, .trademarksAndNames, .payElsewhere, .similarApps, .links, .inAppProducts,
                .screenshotText,
            ],
            "appInformation": [.ageRating, .userContent, .accountDeletion],
            "catalog": [.subscriptionTerms, .inAppProducts],
            "inAppTexts": [.inAppProducts],
            "compliance": [.chinaSecurityAssessment, .chinaAIContent],
            "privacyURLs": [.links, .subscriptionTerms],
        ]
        return shared.errors.sorted { $0.key < $1.key }.flatMap { part, reason in
            (stops[part] ?? []).map { ReviewRiskGap(check: $0, reason: reason) }
        }
    }
}
