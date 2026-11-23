//
//  KeyCheckFailureTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("KeyCheckFailure")
struct KeyCheckFailureTests {
    @Test func appleAnswersMapToTheDesignsErrors() {
        #expect(KeyCheckFailure(AppStoreConnectError.unauthorized) == .rejected)
        #expect(KeyCheckFailure(AppStoreConnectError.forbidden(detail: "role")) == .roleTooLow)
        #expect(KeyCheckFailure(AppStoreConnectError.rateLimited)
            == .other("Apple’s hourly limit was reached. Try again in a few minutes.\nDetails: HTTP 429"))
    }

    @Test(arguments: [URLError.Code.notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .timedOut])
    func networkErrorsMeanOffline(code: URLError.Code) {
        #expect(KeyCheckFailure(URLError(code)) == .offline)
    }

    @Test func otherURLErrorsSayWhatToDoAndKeepTheirMessageInDetails() {
        let error = URLError(.badServerResponse)
        #expect(KeyCheckFailure(error) == .other("Try again in a minute.\nDetails: \(error.localizedDescription) (URLError \(error.code.rawValue))"))
    }

    @Test func titlesNameTheStatusCode() {
        #expect(KeyCheckFailure.rejected.title.contains("401"))
        #expect(KeyCheckFailure.roleTooLow.title.contains("403"))
        #expect(KeyCheckFailure.roleTooLow.message.contains("App Manager"))
        #expect(KeyCheckFailure.other("Nope").message == "Nope")
    }
}
