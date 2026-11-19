//
//  StoreTextGuidelinePlaceTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The rules of the texts outside the store listing: In-App Events (2.3.13
/// and Apple's In-App Events page), retention messages (App Store Connect's
/// content guidelines) and review replies (5.6.1). Each place looks for
/// its own things: an event may be free, a reply may say "feel free".
@Suite("StoreTextGuidelineCheck · events, retention messages, replies")
struct StoreTextGuidelinePlaceTests {
    private func kinds(_ text: String, _ place: StoreTextGuidelinePlace) -> [StoreTextGuidelineKind] {
        StoreTextGuidelineCheck.issues(in: text, for: place).map(\.kind)
    }

    private func phrases(_ text: String, _ place: StoreTextGuidelinePlace) -> [String] {
        StoreTextGuidelineCheck.issues(in: text, for: place).flatMap(\.phrases)
    }

    // MARK: - In-App Events

    @Test(arguments: ["Only $4.99 this weekend", "Every theme for 4,99 €", "50% off all themes", "Special offer: Pro unlocked"])
    func anEventWithAPriceIsRejected(text: String) {
        #expect(kinds(text, .eventText) == [.pricing])
    }

    @Test func anEventPriceSaysWhichPageForbidsIt() throws {
        let issue = try #require(StoreTextGuidelineCheck.issues(in: "Pro for $4.99", for: .eventText).first)
        #expect(issue.message == "App Review rejects specific prices in In-App Event texts (Guideline 2.3.13): “$4.99”.")
        #expect(issue.json["guideline"] == "2.3.13")
        #expect(issue.assistantReason.contains("purchase requirement"))
    }

    /// A free weekend is an event: Apple's page bans prices, not "free".
    @Test(arguments: ["Free Weekend", "Every theme is free to try this week", "A 7-day challenge", "Share your best shot of the week"])
    func whatAnEventMaySay(text: String) {
        #expect(kinds(text, .eventText).isEmpty)
    }

    @Test(arguments: ["The #1 Photo Challenge", "Our award-winning challenge", "The best app event of the year", "Join 90% of users"])
    func claimsThatCantBeVerified(text: String) {
        #expect(kinds(text, .eventText).contains(.unverifiableClaim))
    }

    @Test(arguments: ["DON'T MISS OUT", "HUGE SUMMER EVENT", "Join now!!!", "Ready?!", "Can you finish it??"])
    func allCapitalsAndRepeatedPunctuation(text: String) {
        #expect(kinds(text, .eventText) == [.emphasis])
    }

    @Test(arguments: ["New AI prompts", "HDR Photo Week", "A WWDC watch party", "Join now!", "Ready? Set. Go."])
    func acronymsAndOnePunctuationMarkPass(text: String) {
        #expect(kinds(text, .eventText).isEmpty)
    }

    @Test func otherPlatformsPlaceholdersAndKidsTermsToo() {
        #expect(kinds("Also on Android", .eventText) == [.otherPlatform])
        #expect(kinds("Lorem ipsum dolor", .eventText) == [.placeholder])
        #expect(kinds("A challenge for kids", .eventText) == [.kidsTerms])
    }

    /// The listing's other rules aren't the event's: an event is often
    /// "coming soon", and "beta" can be a beta event.
    @Test func comingSoonIsAnEventsBusiness() {
        #expect(kinds("New levels coming soon", .eventText).isEmpty)
    }

    // MARK: - Retention messages

    @Test(arguments: [
        "Stay and get 50% off", "One month free if you stay", "Keep Pro for $2.99", "Your 7-day trial ends today", "A special offer for you",
    ])
    func aRetentionMessageWithAnOfferIsRejected(text: String) {
        #expect(kinds(text, .retentionMessage) == [.pricing])
    }

    @Test func aRetentionMessageNamesItsGuidelines() throws {
        let issue = try #require(StoreTextGuidelineCheck.issues(in: "Stay for 50% off", for: .retentionMessage).first)
        let rule = "App Review rejects offers, discounts and prices in retention messages"
        #expect(issue.message == "\(rule) (App Store Connect’s retention message guidelines): “50% off”.")
    }

    /// Apple's own examples of what's fine: a factual loss, key features,
    /// upcoming content.
    @Test(arguments: [
        "You'll lose access to downloaded content when your subscription ends",
        "Your entries stay; prompts, photos and search end with this period.",
        "New guided journals are coming soon",
        "Feel free to come back anytime",
    ])
    func whatARetentionMessageMaySay(text: String) {
        #expect(kinds(text, .retentionMessage).isEmpty)
    }

    @Test func statisticsAndSuperlativesAreClaims() {
        #expect(phrases("92% of parents say it helps", .retentionMessage) == ["92% of parents"])
        #expect(kinds("The best app for your journal", .retentionMessage) == [.unverifiableClaim])
        #expect(kinds("WAIT, DON'T GO!!", .retentionMessage) == [.emphasis])
    }

    // MARK: - Review replies

    @Test(arguments: ["Use code SPRING for 50% off", "Here's a promo code for you", "Pro is just $4.99 now"])
    func aReplyWithMarketingIsRejected(text: String) {
        #expect(kinds(text, .reviewReply) == [.pricing])
    }

    @Test func aReplyNamesGuideline561() throws {
        let issue = try #require(StoreTextGuidelineCheck.issues(in: "Use code SPRING", for: .reviewReply).first)
        #expect(issue.message == "Replies to reviews can’t include marketing (Guideline 5.6.1): “Use code SPRING”.")
    }

    /// A support answer: "free" and trials aren't marketing here, nor is
    /// excitement or a "coming soon".
    @Test(arguments: [
        "Feel free to write to us at support.",
        "The free trial lasts 7 days; cancel in Settings before it ends.",
        "Thank you!! The fix is coming soon.",
        "We're the best people to ask: write to us.",
    ])
    func whatAReplyMaySay(text: String) {
        #expect(kinds(text, .reviewReply).isEmpty)
    }

    @Test(arguments: ["Hi [name], thanks for writing", "Dear {customer}, sorry", "Thanks {{first_name}}!"])
    func aReplyTemplateLeftUnfilledIsPlaceholderText(text: String) {
        #expect(kinds(text, .reviewReply) == [.placeholder])
    }

    // MARK: - The places and the listing

    /// The listing keeps its rules: "free" is still pricing there, and the
    /// emphasis check is only the places'.
    @Test func theListingIsntChanged() {
        #expect(StoreTextGuidelineCheck.issues(in: "Free Weekend", for: .promotionalText).map(\.kind) == [.pricing])
        #expect(StoreTextGuidelineCheck.issues(in: "DON'T MISS OUT!!", for: .promotionalText).isEmpty)
        #expect(!StoreTextGuidelineKind.emphasis.checksCaptions)
    }

    @Test func eachPlaceHasRulesForTheTools() {
        for place in StoreTextGuidelinePlace.allCases {
            #expect(!place.summary.isEmpty)
            #expect(place.rulesJSON.arrayValue?.isEmpty == false)
        }
    }
}
