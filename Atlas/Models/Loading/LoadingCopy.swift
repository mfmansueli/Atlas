//
//  LoadingCopy.swift
//  Atlas
//

import Foundation

/// Every skeleton's words, in one place so the copy lint and the tests see
/// them together (README-DS §9: "Reading 6 apps from Apple…").
enum LoadingCopy {
    // MARK: - Library

    static var apps: LoadingMessage {
        LoadingMessage(
            spoken: String(localized: "Loading your apps", comment: "kind:loading"),
            line: String(localized: "Reading apps from App Store Connect…", comment: "kind:loading")
        )
    }

    static var overview: LoadingMessage {
        LoadingMessage(spoken: String(localized: "Loading the overview", comment: "kind:loading"))
    }

    // MARK: - Sections

    static var storePage: LoadingMessage {
        LoadingMessage(spoken: String(localized: "Loading the Store Page", comment: "kind:loading"))
    }

    static var inAppTexts: LoadingMessage {
        LoadingMessage(spoken: String(localized: "Loading the In-App Purchase texts", comment: "kind:loading"))
    }

    static var screenshots: LoadingMessage {
        LoadingMessage(
            spoken: String(localized: "Loading the screenshots", comment: "kind:loading"),
            line: String(localized: "Reading screenshots from Apple…", comment: "kind:loading")
        )
    }

    static var appStoreScreenshots: LoadingMessage {
        LoadingMessage(
            spoken: String(localized: "Loading the App Store screenshots", comment: "kind:loading"),
            line: String(localized: "Reading App Store screenshots…", comment: "kind:loading")
        )
    }

    static func productPages(appName: String) -> LoadingMessage {
        LoadingMessage(
            spoken: String(localized: "Loading the product pages", comment: "kind:loading"),
            line: String(localized: "Reading \(appName)’s product pages…", comment: "kind:loading")
        )
    }

    static var defaultPageScreenshots: LoadingMessage {
        LoadingMessage(
            spoken: String(localized: "Loading the default page’s screenshots", comment: "kind:loading"),
            line: String(localized: "Reading the default page’s screenshots…", comment: "kind:loading")
        )
    }

    static var events: LoadingMessage {
        LoadingMessage(spoken: String(localized: "Loading the In-App Events", comment: "kind:loading"))
    }

    static var nominations: LoadingMessage {
        LoadingMessage(spoken: String(localized: "Loading the nominations", comment: "kind:loading"))
    }

    static var appInformation: LoadingMessage {
        LoadingMessage(spoken: String(localized: "Loading App Information", comment: "kind:loading"))
    }

    static var accessibility: LoadingMessage {
        LoadingMessage(spoken: String(localized: "Loading the accessibility labels", comment: "kind:loading"))
    }

    static var privacyURLs: LoadingMessage {
        LoadingMessage(spoken: String(localized: "Loading the privacy URLs", comment: "kind:loading"))
    }

    static var reviews: LoadingMessage {
        LoadingMessage(spoken: String(localized: "Loading the reviews", comment: "kind:loading"))
    }

    static func analytics(appName: String) -> LoadingMessage {
        LoadingMessage(
            spoken: String(localized: "Loading Apple’s reports", comment: "kind:loading"),
            line: String(localized: "Downloading Apple’s reports for \(appName)…", comment: "kind:loading")
        )
    }

    static var analyticsCheck: LoadingMessage {
        LoadingMessage(
            spoken: String(localized: "Checking Apple’s reports", comment: "kind:loading"),
            line: String(localized: "Checking Apple’s reports…", comment: "kind:loading")
        )
    }

    // MARK: - Sheets

    static var builds: LoadingMessage {
        LoadingMessage(
            spoken: String(localized: "Loading the builds", comment: "kind:loading"),
            line: String(localized: "Checking for new builds…", comment: "kind:loading")
        )
    }

    static var assetLibrary: LoadingMessage {
        LoadingMessage(
            spoken: String(localized: "Loading the Asset Library", comment: "kind:loading"),
            line: String(localized: "Reading the Asset Library…", comment: "kind:loading")
        )
    }

    static var plans: LoadingMessage {
        LoadingMessage(
            spoken: String(localized: "Loading the plans", comment: "kind:loading"),
            line: String(localized: "Getting plans from the App Store…", comment: "kind:loading")
        )
    }

    static var pushScreenshots: LoadingMessage {
        LoadingMessage(
            spoken: String(localized: "Loading the screenshots to push", comment: "kind:loading"),
            line: String(localized: "Checking screenshots against App Store Connect…", comment: "kind:loading")
        )
    }

    /// Every fixed message, for the tests; `sampleAppName` fills the ones
    /// that name the app.
    static func all(sampleAppName: String) -> [LoadingMessage] {
        [
            apps, overview, storePage, inAppTexts, screenshots, appStoreScreenshots, productPages(appName: sampleAppName),
            defaultPageScreenshots, events, nominations, appInformation, accessibility, privacyURLs, reviews,
            analytics(appName: sampleAppName), analyticsCheck, builds, assetLibrary, plans, pushScreenshots,
        ]
    }
}
