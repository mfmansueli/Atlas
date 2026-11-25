//
//  ReviewShotsAskPrompt.swift
//  Atlas
//

import Foundation

/// What Make Review Screenshots… asks the assistant (README — Pricing:
/// review screenshots, “The run”): open the app in Simulator, find the
/// paywall, and for each product missing an App Review screenshot select
/// its plan, wait for its price, capture, check and send the image as a
/// suggestion. Nothing is bought, accepted or pushed.
enum ReviewShotsAskPrompt {
    /// Its own session and permissions: build, open the paywall in a
    /// simulator, upload to the review screenshot link; with `storeKit`
    /// also add a StoreKit configuration to the project.
    static func purpose(storeKit: Bool) -> ClaudeCodeRunPurpose {
        .reviewScreenshots(addsStoreKit: storeKit)
    }

    /// The toolbar's and the toast's name for the run.
    static var subject: String { String(localized: "Pricing · review screenshots") }

    /// A product to capture, as the prompt names it.
    struct Product: Equatable {
        var name: String
        var productID: String
        /// “Monthly”.
        var plan: String
        /// “$4.99”, Pricing's U.S. price.
        var usPrice: String?
    }

    /// “Bruma” for “Bruma – Gay Dating Nearby”, “Alba” for “Alba: Daily
    /// Motivation”: the name people see on the Home Screen, near enough.
    static func shortName(_ name: String) -> String {
        let cut = name.components(separatedBy: CharacterSet(charactersIn: ":–—|")).first ?? name
        let short = cut.replacingOccurrences(of: " - ", with: "\u{1}").components(separatedBy: "\u{1}").first ?? cut
        let trimmed = short.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? name : trimmed
    }

    static func text(app: String, appID: StoreApp.ID, products: [Product], route: String?) -> String {
        let short = shortName(app)
        let list = products.map { product in
            let price = product.usPrice.map { ", \($0) in the United States" } ?? ""
            return "- \(product.name) (\(product.productID)): select \(product.plan)\(price)"
        }.joined(separator: "\n")
        let way = route.map {
            "The person said the paywall is here: \($0). Go there first."
        } ?? """
        Find the paywall: a deep link or route in the code first (search for the paywall view and how it's presented), then \
        the app's visible ways in (Settings, a locked feature, a Pro or Plus badge).
        """
        return """
        Make the App Review screenshots of \(app)'s in-app purchases in Atlas (appId \(appID)). Each product needs a picture \
        of its purchase screen, usually the paywall, with its own plan selected. Only App Review sees them.

        Products missing one, in the paywall's order:
        \(list)

        1. Call get_subscriptions for reviewScreenshotUploadURL. Report each step with report_review_screenshot_run \
        (status "working", a short step such as "Opened \(short) in Simulator · iPhone 17 Pro", and productId while you \
        capture that product), so Atlas shows it.
        2. Build the app's current scheme for the iPhone 17 Pro Simulator, in the app's development language, and \
        launch it. Set a clean status bar (xcrun simctl status_bar booted override --time 9:41 --batteryState charged \
        --batteryLevel 100).
        3. \(way) If nothing leads to a purchase screen, call report_review_screenshot_run with status \
        "paywall_not_found" and what you tried in tried, and stop.
        4. If the paywall opens but shows no prices (products not returned by StoreKit), capture it, send the PNG to \
        reviewScreenshotUploadURL as below, call report_review_screenshot_run with status "no_prices", what you saw in \
        saw and the fileId in sawFileId, and stop. Don't fake prices.
        5. For each product: select its plan (you can't tap: use a deep link, launch arguments, a debug scene or the \
        project's UI tests; if none selects it, a capture where its plan and price show is fine), wait for its price, and \
        capture with xcrun simctl io booted screenshot. \
        Check the image: the price shows and matches, the right plan is selected, no keyboard, alert, spinner, debug or \
        TestFlight banner. One more try if a check fails; if it fails again, call report_review_screenshot_run with \
        status "check_failed", the productId and the check in reason, and go on with the next product. If the paywall \
        doesn't show a product, report status "skipped" with the productId and why in reason. Send the PNG to reviewScreenshotUploadURL with exactly \
        curl -s --data-binary @<file> -H 'Content-Type: image/png' '<url>?name=<productId>.png' (single quotes) and call \
        propose_purchase_review_screenshot with appId, \
        productId, the fileId, planShown (only the selected plan's name, such as Annual, even when it's another \
        product's), price, device "iPhone 17 Pro", language and the checks it passed. It arrives \
        as a suggestion; the person accepts it.
        6. Never tap the purchase button and never buy anything: stop before the purchase sheet. Never accept, push or \
        change the products. When every product is done, call report_review_screenshot_run with status "done".
        """
    }

    /// Add StoreKit Configuration…: a local `.storekit` file so the
    /// paywall shows prices in Simulator, then the screenshots again.
    static func storeKit(app: String, appID: StoreApp.ID, products: [Product], route: String?) -> String {
        let list = products.map { "- \($0.productID) (\($0.name)\($0.usPrice.map { ", \($0)" } ?? ""))" }.joined(separator: "\n")
        return """
        \(app)'s paywall showed no prices in Simulator: StoreKit returned none of its products. Add a StoreKit \
        configuration to the Xcode project so it does, then make the review screenshots.

        - Make \(shortName(app)).storekit with these products, their IDs and U.S. prices. When they already exist in App Store \
        Connect, make a synced StoreKit configuration rather than a local one.
        \(list)
        - Set it in the Run action's options of the scheme you build, and nowhere else: it isn't used by archives or \
        uploads. Say in your last message which files you changed; never commit.

        Then:

        \(text(app: app, appID: appID, products: products, route: route))
        """
    }
}
