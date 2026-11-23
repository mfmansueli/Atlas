//
//  ProductPageCreateRecoveryTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A new custom product page Apple answers with a server error (on Alba,
/// 500 `UNEXPECTED_ERROR` for a 14-language page it then made): Atlas looks
/// for the page by name and goes on with it, makes the languages Apple
/// didn't, and never sends the create a second time by itself. A page it
/// can't find says so, and a retry takes the page once it's there.
@MainActor
@Suite("A new page Apple failed on")
struct ProductPageCreateRecoveryTests {
    typealias Sample = DebugProductPagesData

    static let unexpected = AppStoreConnectError.server(
        statusCode: 500, code: "UNEXPECTED_ERROR",
        detail: "An unexpected error occurred on the server side. If this issue continues, contact us at https://developer.apple.com/contact/."
    )
    private static let keywordsPath = "/relationships/searchKeywords"

    private let queue = ChangeQueue()

    private func change() throws -> PendingChange {
        let change = try #require(ProductPageChangeBuilder(appID: "lumen").newPageChange(Sample.privateDiary, defaultPage: Sample.defaultPage))
        #expect(!change.isBlocked)
        return change
    }

    private func push(_ transport: FakeNewPageTransport) async throws -> PushController {
        let controller = PushController(queue: queue, history: PushHistory(), transport: transport)
        controller.productPagePacing = .immediate
        try queue.upsert(contentsOf: [change()])
        controller.push(queue.changes)
        await controller.waitUntilFinished()
        return controller
    }

    private func failureText(_ controller: PushController) -> String? {
        guard case let .failed(text) = controller.items.first?.status else { return nil }
        return text
    }

    @Test func thePageAppleMadeAnywayIsTakenAndTheChangeGoesOn() async throws {
        let transport = FakeNewPageTransport(.init(createFailure: Self.unexpected, hiddenForLooks: 1))
        let controller = try await push(transport)

        #expect(controller.items.first?.status == .done)
        #expect(controller.items.first?.createdIDs["appCustomProductPages"] == FakeNewPageTransport.pageID)
        #expect(transport.log.count { $0 == "create page" } == 1)
        // The pre-check, a look that doesn't find it yet, one that does.
        #expect(transport.log.count { $0 == "list pages" } == 3)
        let keywords = transport.log.filter { $0.hasPrefix("keywords") }
        #expect(Set(keywords) == Set(Sample.privateDiary.locales.map { "keywords loc-\($0)" }))
        #expect(!transport.log.contains { $0.hasPrefix("create language") })
        #expect(queue.changes.isEmpty)
    }

    @Test func languagesAppleDidntMakeAreMadeWithTheirTexts() async throws {
        let transport = FakeNewPageTransport(.init(createFailure: Self.unexpected, madeLocales: ["en-US"]))
        let controller = try await push(transport)

        #expect(controller.items.first?.status == .done)
        #expect(Set(transport.log.filter { $0.hasPrefix("create language") }) == ["create language de-DE", "create language ja", "create language ar-SA"])
        #expect(transport.text(of: "ar-SA") == Sample.privateDiary.promotionalTexts["ar-SA"])
        #expect(transport.text(of: "ja") == "")
    }

    @Test func aPageThatDoesntShowUpIsNeverMadeAgain() async throws {
        let transport = FakeNewPageTransport(.init(createFailure: Self.unexpected, madeAnyway: false))
        let controller = try await push(transport)

        let text = try #require(failureText(controller))
        #expect(text.contains("\nDetails: UNEXPECTED_ERROR"))
        #expect(text.contains("may still be making it"))
        #expect(!text.contains(PushController.serverFailureText))
        #expect(transport.log.count { $0 == "create page" } == 1)
        #expect(transport.log.count { $0 == "list pages" } == 1 + ProductPagePushPacing.immediate.looks.count)
        #expect(controller.items.first?.mayHaveMadePage == "Private diary")
        #expect(queue.changes.count == 1)
    }

    @Test func aRetryGoesOnWithThePageOnceAppleFinishedIt() async throws {
        let transport = FakeNewPageTransport(.init(createFailure: Self.unexpected, madeAnyway: false))
        let controller = try await push(transport)
        #expect(failureText(controller) != nil)

        transport.finishPage()
        controller.retryFailed()
        await controller.waitUntilFinished()

        #expect(controller.items.first?.status == .done)
        #expect(transport.log.count { $0 == "create page" } == 1)
        #expect(transport.log.count { $0.hasPrefix("keywords") } == Sample.privateDiary.locales.count)
    }

    @Test func pushingItAgainAfterTheSheetClosedGoesOnWithThePageToo() async throws {
        let transport = FakeNewPageTransport(.init(createFailure: Self.unexpected, madeAnyway: false))
        let controller = try await push(transport)
        controller.dismissFinished()

        transport.finishPage()
        controller.push(queue.changes)
        await controller.waitUntilFinished()

        #expect(controller.items.first?.status == .done)
        #expect(transport.log.count { $0 == "create page" } == 1)
    }

    @Test func aPageListedWithoutItsVersionYetWaitsForARetry() async throws {
        let transport = FakeNewPageTransport(.init(createFailure: Self.unexpected, versionReady: false))
        let controller = try await push(transport)

        let text = try #require(failureText(controller))
        #expect(text.contains("Apple is still making “Private diary”."))
        #expect(controller.items.first?.mayHaveMadePage == "Private diary")
        #expect(!transport.log.contains("create version"))

        transport.finishPage()
        controller.retryFailed()
        await controller.waitUntilFinished()
        #expect(controller.items.first?.status == .done)
        #expect(transport.log.count { $0 == "create page" } == 1)
    }

    @Test func aTimeoutIsLookedForLikeAServerError() async throws {
        let transport = FakeNewPageTransport(.init(createFailure: URLError(.timedOut)))
        let controller = try await push(transport)
        #expect(controller.items.first?.status == .done)
    }

    @Test func aBadRequestIsntLookedFor() async throws {
        let badRequest = AppStoreConnectError.server(statusCode: 400, code: "PARAMETER_ERROR.INVALID", detail: "name is invalid.")
        let transport = FakeNewPageTransport(.init(createFailure: badRequest, madeAnyway: false))
        let controller = try await push(transport)

        #expect(controller.items.first?.status == .failed(badRequest.pushFailureText))
        #expect(transport.log.count { $0 == "list pages" } == 1)
        #expect(controller.items.first?.mayHaveMadePage == nil)
    }

    @Test func aPageAnotherPushMadeIsStillRefused() async throws {
        let transport = FakeNewPageTransport(.init(pageBefore: true))
        let controller = try await push(transport)

        #expect(controller.items.first?.status == .failed(ProductPageAlreadyMade(name: "Private diary").errorDescription ?? ""))
        #expect(!transport.log.contains("create page"))
    }

    @Test func aLanguageWriteApplesServerFailsOnIsSentOnceMore() async throws {
        let transport = FakeNewPageTransport(.init(failures: [Self.keywordsPath: (Self.unexpected, 1)]))
        let controller = try await push(transport)

        #expect(controller.items.first?.status == .done)
        #expect(transport.log.count { $0.hasPrefix("failed") } == 1)
        #expect(transport.log.count { $0.hasPrefix("keywords") } == Sample.privateDiary.locales.count)
    }

    @Test func aLanguageWriteThatKeepsFailingSaysWhichAndThatARetryGoesOn() async throws {
        let transport = FakeNewPageTransport(.init(failures: [Self.keywordsPath: (Self.unexpected, 2)]))
        let controller = try await push(transport)

        let text = try #require(failureText(controller))
        let first = Sample.privateDiary.locales[0]
        #expect(text.contains("“Private diary” is in App Store Connect"))
        #expect(text.contains("\(ProductPageField.keywords.title) · \(ProductPageChangeBuilder.localeName(first))"))
        #expect(text.contains("UNEXPECTED_ERROR"))
        #expect(!text.contains(PushController.serverFailureText))
        #expect(controller.items.first?.sentRequestCount == 1)

        controller.retryFailed()
        await controller.waitUntilFinished()
        #expect(controller.items.first?.status == .done)
        #expect(transport.log.count { $0 == "create page" } == 1)
    }

    /// A language an earlier try made although Apple failed on it: making
    /// it again is refused as a duplicate, so the write goes into it.
    @Test func aLanguageMadeMeanwhileIsWrittenInto() async throws {
        let transport = FakeNewPageTransport(.init(initialLocales: ["de-DE"], lateLocales: ["de-DE"]))
        let write = ProductPageLocaleWrite(.init(
            pageID: FakeNewPageTransport.pageID, locale: "de-DE", promotionalText: "Dein Tagebuch.", addKeywords: ["tagebuch"]
        ))

        let sent = try await write.send(via: transport, knownVersionID: FakeNewPageTransport.versionID)

        #expect(sent.localizationID == "loc-de-DE")
        #expect(transport.log == ["languages", "create language de-DE", "languages", "text loc-de-DE", "keywords loc-de-DE"])
    }
}
