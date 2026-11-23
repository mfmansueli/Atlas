//
//  ProductPageCreateTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What a new page's create request carries for a recovery (its name, deep
/// link and inline languages), which failures may have gone through, and
/// what a failed row says.
@MainActor
@Suite("A new page's create")
struct ProductPageCreateTests {
    typealias Sample = DebugProductPagesData

    @Test func itReadsTheNameDeepLinkAndLanguagesOfTheRequest() throws {
        let change = try #require(ProductPageChangeBuilder(appID: "lumen").newPageChange(Sample.privateDiary, defaultPage: Sample.defaultPage))
        let request = try #require(change.requests.first)
        let create = try #require(ProductPageCreate(request))

        #expect(create.name == "Private diary")
        #expect(create.deepLink == "https://lumen.app/lock")
        #expect(create.languages.map(\.locale) == Sample.privateDiary.locales)
        #expect(create.languages.first { $0.locale == "ar-SA" }?.promotionalText == Sample.privateDiary.promotionalTexts["ar-SA"])
        #expect(create.languages.first { $0.locale == "ja" }?.promotionalText == nil)
        #expect(ProductPageCreate(change.requests[1]) == nil)
    }

    @Test func onlyAServerFailureOrATimeoutMayHaveGoneThrough() {
        #expect(PushController.mayHaveGoneThrough(ProductPageCreateRecoveryTests.unexpected))
        #expect(PushController.mayHaveGoneThrough(AppStoreConnectError.server(statusCode: 503, detail: nil)))
        #expect(PushController.mayHaveGoneThrough(URLError(.timedOut)))
        #expect(!PushController.mayHaveGoneThrough(AppStoreConnectError.server(statusCode: 400, code: "PARAMETER_ERROR.INVALID", detail: nil)))
        #expect(!PushController.mayHaveGoneThrough(AppStoreConnectError.rejected(statusCode: 409, code: "ENTITY_ERROR", detail: nil)))
        #expect(!PushController.mayHaveGoneThrough(URLError(.notConnectedToInternet)))
    }

    /// A 400 was refused outright: no "may still have gone through".
    @Test func aBadRequestDoesntSayItMayHaveGoneThrough() {
        #expect(PushController.timedOutStatus(AppStoreConnectError.server(statusCode: 400, detail: "Bad")) == nil)
        #expect(PushController.timedOutStatus(ProductPageCreateRecoveryTests.unexpected) != nil)
    }

    @Test func aPageNotFoundSaysWhatAtlasDidAndWhatARetryDoes() {
        let failure = ProductPageNotConfirmed(
            name: "Affirmations & Confidence", error: ProductPageCreateRecoveryTests.unexpected, pageSeen: false, looked: .seconds(110)
        )
        let text = failure.errorDescription ?? ""
        #expect(text.hasPrefix("“Affirmations & Confidence” isn’t in App Store Connect after"))
        #expect(text.contains("may still be making it"))
        #expect(text.contains("Atlas won’t make a duplicate.\nDetails: UNEXPECTED_ERROR — An unexpected error occurred"))

        let timedOut = ProductPageNotConfirmed(name: "A", error: URLError(.timedOut), pageSeen: true, looked: .zero)
        #expect(timedOut.errorDescription?.hasPrefix("Apple is still making “A”.") == true)
        #expect(timedOut.errorDescription?.hasSuffix("\nDetails: Apple didn’t answer in time.") == true)
        let seen = ProductPageNotConfirmed(name: "A", error: nil, pageSeen: true, looked: .zero).errorDescription
        #expect(seen == "Apple is still making “A”. Retry in a few minutes; Atlas continues with that page, not a new one.")
    }

    @Test func aStepIsNamedByWhatItWrites() {
        let german = ProductPageChangeBuilder.localeName("de-DE")
        #expect(ProductPageStepFailure.step(.init(pageID: "p", locale: "de-DE", addKeywords: ["a"])) == "\(ProductPageField.keywords.title) · \(german)")
        #expect(ProductPageStepFailure.step(.init(pageID: "p", locale: "de-DE", promotionalText: "Hallo")) == "\(ProductPageField.promotionalText.title) · \(german)")
        #expect(ProductPageStepFailure.step(.init(pageID: "p", deepLink: "https://a.app/x")) == ProductPageField.deepLink.title)
    }

    @Test func onlyALaterStepOfANewPageIsSaidAsOne() throws {
        let change = try #require(ProductPageChangeBuilder(appID: "lumen").newPageChange(Sample.privateDiary, defaultPage: Sample.defaultPage))
        var item = PushItem(change: change)
        #expect(ProductPageStepFailure(item, error: ProductPageCreateRecoveryTests.unexpected) == nil)
        item.sentRequestCount = 2
        let failure = try #require(ProductPageStepFailure(item, error: ProductPageCreateRecoveryTests.unexpected))
        #expect(failure.step.hasSuffix(ProductPageChangeBuilder.localeName(Sample.privateDiary.locales[1])))

        let rateLimited = ProductPageStepFailure.status(
            .notSent("Rate limited"), stop: "Rate limited", error: AppStoreConnectError.rateLimited, item: item
        )
        #expect(rateLimited == .notSent("Rate limited"))
    }
}
