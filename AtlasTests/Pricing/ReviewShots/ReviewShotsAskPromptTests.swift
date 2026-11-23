//
//  ReviewShotsAskPromptTests.swift
//  AtlasTests
//

#if DEBUG
import Testing
@testable import Atlas

/// What Make Review Screenshots… asks: each product with its plan and
/// price, the tools to report and propose with, and the rules (never buy,
/// accept or push).
@Suite("ReviewShotsAskPrompt")
struct ReviewShotsAskPromptTests {
    private let products = [
        ReviewShotsAskPrompt.Product(name: "Lumen Plus Monthly", productID: "lumen.plus.monthly", plan: "Monthly", usPrice: "$4.99"),
        ReviewShotsAskPrompt.Product(name: "Lumen Lifetime", productID: "lumen.lifetime", plan: "Lifetime", usPrice: nil),
    ]

    @Test func itNamesEachProductAndTheTools() {
        let prompt = ReviewShotsAskPrompt.text(app: "Lumen", appID: "app1", products: products, route: nil)
        #expect(prompt.contains("- Lumen Plus Monthly (lumen.plus.monthly): select Monthly, $4.99 in the United States"))
        #expect(prompt.contains("- Lumen Lifetime (lumen.lifetime): select Lifetime"))
        for tool in ["get_subscriptions", "report_review_screenshot_run", "propose_purchase_review_screenshot", "paywall_not_found", "no_prices"] {
            #expect(prompt.contains(tool), "\(tool)")
        }
        #expect(prompt.contains("never buy anything"))
        #expect(prompt.contains("iPhone 17 Pro"))
        #expect(prompt.contains("deep link"))
        // The allow rule matches the link in single quotes, not double.
        #expect(prompt.contains("'<url>?name=<productId>.png'"))
        #expect(!prompt.contains("\"<url>"))
    }

    @Test func theAppGoesByItsShortName() {
        #expect(ReviewShotsAskPrompt.shortName("Bruma – Gay Dating Nearby") == "Bruma")
        #expect(ReviewShotsAskPrompt.shortName("Alba: Daily Motivation") == "Alba")
        #expect(ReviewShotsAskPrompt.shortName("Cue Studio - Teleprompter") == "Cue Studio")
        #expect(ReviewShotsAskPrompt.shortName("Bello Hub") == "Bello Hub")
        let prompt = ReviewShotsAskPrompt.storeKit(app: "Bruma – Gay Dating Nearby", appID: "app1", products: products, route: nil)
        #expect(prompt.contains("Bruma.storekit"))
    }

    @Test func aRouteThePersonGaveGoesFirst() {
        let prompt = ReviewShotsAskPrompt.text(app: "Lumen", appID: "app1", products: products, route: "Settings → Lumen Plus")
        #expect(prompt.contains("The person said the paywall is here: Settings → Lumen Plus."))
    }

    @Test func storeKitAddsTheConfigurationFirst() {
        let prompt = ReviewShotsAskPrompt.storeKit(app: "Lumen", appID: "app1", products: products, route: nil)
        #expect(prompt.contains("Lumen.storekit"))
        #expect(prompt.contains("- lumen.plus.monthly (Lumen Plus Monthly, $4.99)"))
        #expect(prompt.contains("Run action"))
        #expect(prompt.contains("report_review_screenshot_run"))
    }
}
#endif
