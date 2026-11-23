//
//  AppleErrorCopyTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("AppleErrorCopy")
struct AppleErrorCopyTests {
    @Test func aServerFailureSaysToTryAgainAndKeepsTheCodeInDetails() {
        let copy = AppleErrorCopy("Prices didn’t load.", error: AppStoreConnectError.server(statusCode: 503, detail: nil))
        #expect(copy.summary == "Prices didn’t load. Apple didn’t answer. Try again in a minute.")
        #expect(copy.details == "HTTP 503")
    }

    @Test func aRefusedChangeKeepsApplesCodeAndText() {
        let error = AppStoreConnectError.rejected(statusCode: 409, code: "ENTITY_ERROR", detail: "Not available.")
        let copy = AppleErrorCopy("The price wasn’t saved.", error: error)
        #expect(copy.summary == "The price wasn’t saved. Apple refused the change. See Details.")
        #expect(copy.details == "ENTITY_ERROR — Not available.")
    }

    @Test func aForbiddenKeyAsksForAnotherRole() {
        let copy = AppleErrorCopy("Analytics didn’t load.", error: AppStoreConnectError.forbidden(detail: nil))
        #expect(copy.summary.hasSuffix("Use an Admin or App Manager key."))
        #expect(copy.details == "FORBIDDEN_ERROR")
    }

    @Test func beingOfflineSaysToCheckTheConnection() {
        let copy = AppleErrorCopy("Reviews didn’t load.", error: URLError(.notConnectedToInternet))
        #expect(copy.summary == "Reviews didn’t load. Atlas can’t reach Apple. Check your connection and try again.")
        #expect(copy.details?.contains("URLError -1009") == true)
    }

    @Test func aCancelledTaskAddsNoStepAndNoDetails() {
        let copy = AppleErrorCopy("Stopped.", error: CancellationError())
        #expect(copy.summary == "Stopped.")
        #expect(copy.details == nil)
        #expect(copy.text == "Stopped.")
    }

    @Test func textPutsDetailsOnTheirOwnLine() {
        let copy = AppleErrorCopy(summary: "Didn’t load. Try again.", details: "HTTP 500")
        #expect(copy.text == "Didn’t load. Try again.\nDetails: HTTP 500")
    }

    @Test func blankDetailsAreDropped() {
        #expect(AppleErrorCopy(summary: "Didn’t load.", details: "  \n").details == nil)
    }

    @Test func anyOtherErrorSaysToTryAgainAndKeepsItsDomain() {
        let error = NSError(domain: "AVFoundationErrorDomain", code: -11800)
        let copy = AppleErrorCopy("The video wasn’t made.", error: error)
        #expect(copy.summary == "The video wasn’t made. Try again.")
        #expect(copy.details?.contains("AVFoundationErrorDomain -11800") == true)
    }
}
