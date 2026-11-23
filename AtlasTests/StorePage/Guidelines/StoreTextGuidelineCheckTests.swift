//
//  StoreTextGuidelineCheckTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// What App Review rejects in store text, from the words alone: SimProps
/// 1.0's description and promotional text (rejected under 2.3.7 for
/// pricing), the other rules, and the ordinary words left alone.
@Suite("StoreTextGuidelineCheck")
struct StoreTextGuidelineCheckTests {
    private func kinds(_ text: String, _ field: ListingField = .description) -> [StoreTextGuidelineKind] {
        StoreTextGuidelineCheck.issues(in: text, for: field).map(\.kind)
    }

    private func phrases(_ text: String, _ field: ListingField = .description) -> [String] {
        StoreTextGuidelineCheck.issues(in: text, for: field).flatMap(\.phrases)
    }

    // MARK: - Pricing (2.3.7)

    @Test func simPropsRejectedTextIsPricing() throws {
        let description = """
        SimProps is free to download. Free includes the test pattern camera, Online and Offline for every simulator.
        Pro and Complete are one-time purchases, with no subscription. Try everything free for 7 days; nothing is charged when the trial ends.
        """
        let issue = try #require(StoreTextGuidelineCheck.issues(in: description, for: .description).first)
        #expect(issue.kind == .pricing)
        #expect(issue.phrases == ["free"])
        #expect(issue.message == "App Review rejects pricing in store text and screenshots (Guideline 2.3.7): “free”.")

        let promotional = "Give iOS Simulator apps a working camera and test bad connections, one simulator at a time. Try everything free for 7 days."
        #expect(phrases(promotional, .promotionalText) == ["free"])
    }

    @Test(arguments: [
        "Hands-free recording", "An ad-free experience", "Ad free, always", "Free up space on your Mac", "Feel free to ask",
        "Free-form notes", "Free of ads and trackers", "Freedom to write, carefree", "Distraction free writing", "Your free time, planned",
        "100% private", "Track the prices of what you want to buy", "Find discounts near you", "Version 2.0 is here",
        "Works with PlayStation and Xbox controllers", "Pro unlocks every camera source.",
    ])
    func ordinaryWordsAreLeftAlone(text: String) {
        #expect(StoreTextGuidelineCheck.issues(in: text, for: .description).isEmpty, "\(text)")
    }

    @Test(arguments: [
        ("Free-to-play puzzles", "Free"), ("Free of charge for students", "Free"), ("100% FREE", "FREE"),
        ("Only $4.99 a month", "$4.99"), ("Assine por R$ 9,90", "R$ 9,90"), ("Nur 4,99 € im Monat", "4,99 €"), ("月額500円", "500円"),
        ("USD 5 per year", "USD 5"), ("50% off this week", "50% off"), ("Save 30% with yearly", "Save 30%"),
        ("Start your 7-day free trial", "7-day free trial"), ("A one-month trial for new members", "one-month trial"),
        ("Cancel during the trial period", "trial period"), ("Special offer for launch", "Special offer"),
    ] as [(String, String)])
    func pricesFreeDiscountsAndTrialsAreFound(text: String, phrase: String) {
        #expect(phrases(text) == [phrase], "\(text)")
        #expect(kinds(text) == [.pricing])
    }

    @Test(arguments: [
        ("Baixe grátis", "grátis"), ("Totalmente gratuito", "gratuito"), ("Jetzt kostenlos laden", "kostenlos"),
        ("Téléchargement gratuit", "gratuit"), ("Darmowa aplikacja", "Darmowa"), ("Ücretsiz indir", "Ücretsiz"),
        ("Скачайте бесплатно", "бесплатно"), ("Κατεβάστε δωρεάν", "δωρεάν"), ("無料でダウンロード", "無料"),
        ("免费下载", "免费"), ("무료 다운로드", "무료"), ("تحميل مجاني", "مجاني"),
    ] as [(String, String)])
    func freeIsFoundInTheAppStoresLanguages(text: String, phrase: String) {
        #expect(phrases(text) == [phrase], "\(text)")
    }

    @Test func aPriceIsFoundOnceAndPhrasesOnceWhateverTheirCase() {
        #expect(phrases("R$ 9,90 por mês") == ["R$ 9,90"])
        #expect(phrases("Free. Totally free. FREE!") == ["Free"])
    }

    // MARK: - The other rules

    @Test func otherPlatformsAndStoresAreFound() {
        #expect(phrases("Also on Android and Google Play.") == ["Android", "Google Play"])
        #expect(kinds("Also on Android.", .whatsNew) == [.otherPlatform])
    }

    @Test func claimsAndOtherAppsCountOnlyInTheNameSubtitleAndKeywords() {
        #expect(kinds("The best journal", .subtitle) == [.unverifiableClaim])
        #expect(kinds("#1 teleprompter", .name) == [.unverifiableClaim])
        #expect(kinds("The best journal you'll keep", .description).isEmpty)
        #expect(phrases("reels,instagram,stories", .keywords) == ["instagram"])
        #expect(kinds("Teleprompter for YouTube", .subtitle) == [.otherApp])
        #expect(kinds("Share your takes to YouTube or Instagram.", .description).isEmpty)
    }

    @Test func betasPlaceholdersAndComingSoonAreFound() {
        #expect(kinds("Lumen Beta", .name) == [.prerelease])
        #expect(kinds("Thanks to our beta testers!", .whatsNew).isEmpty)
        #expect(phrases("Lorem ipsum dolor sit amet") == ["Lorem ipsum", "dolor sit amet"])
        #expect(kinds("TODO: write the description") == [.placeholder])
        #expect(kinds("Made by [Insert company name]") == [.placeholder])
        #expect(kinds("TODO en un solo lugar").isEmpty)
        #expect(kinds("Widgets are coming soon.") == [.comingSoon])
        #expect(kinds("More languages coming soon.", .whatsNew).isEmpty)
    }

    @Test func forKidsIsOnlyForTheKidsCategory() {
        #expect(kinds("Bedtime Stories for Kids", .subtitle) == [.kidsTerms])
        #expect(kinds("Histórias para crianças") == [.kidsTerms])
    }

    @Test func severalRulesComeInTheKindsOrder() {
        let issues = StoreTextGuidelineCheck.issues(in: "Free beta, coming soon to Android", for: .promotionalText)
        #expect(issues.map(\.kind) == [.pricing, .otherPlatform, .prerelease, .comingSoon])
    }

    @Test func urlsAndEmptyTextAreNotChecked() {
        #expect(StoreTextGuidelineCheck.issues(in: "https://free.example/android", for: .supportURL).isEmpty)
        #expect(StoreTextGuidelineCheck.issues(in: "  ", for: .description).isEmpty)
    }

    // MARK: - Captions

    @Test func captionsAreCheckedForWhatScreenshotsMayNotShow() {
        #expect(StoreTextGuidelineCheck.issues(inCaption: "Free for 7 days").map(\.kind) == [.pricing])
        #expect(StoreTextGuidelineCheck.issues(inCaption: "Plan your week", subhead: "Now on Android").map(\.kind) == [.otherPlatform])
        #expect(StoreTextGuidelineCheck.issues(inCaption: "The best camera for the Simulator").isEmpty)
    }

    // MARK: - In-app texts

    @Test func inAppTextsFollowTheirOwnRules() {
        func kinds(_ text: String, _ field: InAppTextField) -> [StoreTextGuidelineKind] {
            StoreTextGuidelineCheck.issues(in: text, for: field).map(\.kind)
        }
        // 3.1.1: a non-subscription app's free trial is named "XX-day Trial".
        #expect(kinds("7-day Trial", .purchaseName).isEmpty)
        #expect(kinds("7 dias de teste", .purchaseName).isEmpty)
        #expect(kinds("7-day Trial", .subscriptionName) == [.pricing])
        #expect(kinds("Pro – $4.99", .purchaseName) == [.pricing])
        #expect(kinds("Kostenlos testen", .purchaseDescription) == [.pricing])
        #expect(kinds("The best #1 pack", .purchaseName).isEmpty)
        #expect(kinds("Beta themes pack", .purchaseName).isEmpty)
        #expect(kinds("Android sync coming soon", .subscriptionDescription) == [.otherPlatform, .comingSoon])
        #expect(kinds("Stories for Kids", .subscriptionGroupName) == [.kidsTerms])
    }

    // MARK: - Messages

    @Test func messagesNameTheGuidelinesAndThePhrases() {
        let kids = StoreTextGuidelineIssue(kind: .kidsTerms, phrases: ["for kids"])
        #expect(kids.message == "“For Kids” and “For Children” are only for apps in the Kids Category (Guidelines 2.3.8 and 5.1.4(b)): “for kids”.")
        let many = StoreTextGuidelineIssue(kind: .pricing, phrases: ["free", "$4.99", "50% off", "7-day trial", "special offer"])
        #expect(many.quotedPhrases == "“free”, “$4.99”, “50% off” and 2 more")
        #expect(many.json == ["kind": "pricing", "guideline": "2.3.7", "phrases": ["free", "$4.99", "50% off", "7-day trial", "special offer"]])
        let reason = [kids].assistantReason
        #expect(reason.hasSuffix("Leave it out unless the app is in the Kids Category."))
        #expect([kids].assistantNote.hasPrefix("App Review would reject it: "))
        #expect([kids].assistantNote.hasSuffix(" Suggest a version without it."))
    }

    @Test func everyRuleIsInTheAssistantsRules() {
        for guideline in ["2.3.7", "2.3.10", "2.2", "2.1(a)", "2.3.8", "2.3.12"] {
            #expect(StoreTextRules.all.contains { $0.contains(guideline) }, "\(guideline)")
        }
        #expect(StoreTextRules.summary.contains("“free”"))
    }
}
