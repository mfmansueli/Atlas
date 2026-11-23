//
//  PricingLoadNoticeTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Which banner a failed pricing read raises. Leaving Pricing while it
/// loads cancels the read, which used to show "App Store Connect returned
/// an error · cancelled".
@Suite("PricingLoadNotice")
struct PricingLoadNoticeTests {
    @Test func aCancelledReadRaisesNoBanner() {
        #expect(PricingLoadNotice.notice(for: URLError(.cancelled)) == nil)
        #expect(PricingLoadNotice.notice(for: CancellationError()) == nil)
    }

    @Test func offlineAndRateLimitKeepTheirBanners() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let hour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        #expect(PricingLoadNotice.notice(for: URLError(.notConnectedToInternet)) == .offline)
        #expect(PricingLoadNotice.notice(for: AppStoreConnectError.rateLimited, now: now, calendar: calendar)
            == .rateLimited(resumeAt: hour.addingTimeInterval(3600)))
    }

    @Test func applesErrorsShowInAtlasWordsWithAppleTextInDetails() {
        let error = AppStoreConnectError.server(statusCode: 500, code: "UNEXPECTED_ERROR", detail: nil)
        guard case let .apiError(text) = PricingLoadNotice.notice(for: error) else {
            Issue.record("Expected an API error banner")
            return
        }
        #expect(text.hasPrefix("Prices didn’t load. Apple didn’t answer. Try again in a minute.\nDetails: "))
        #expect(text == AppleErrorCopy("Prices didn’t load.", error: error).text)
    }

    #if DEBUG
    @MainActor
    @Test func theViewModelReportsOnlyRealFailures() async {
        let model = await PricingModelFixtures.viewModel()
        var notices: [PushNotice] = []
        model.onNotice = { notices.append($0) }
        model.reportLoadError(URLError(.cancelled))
        model.reportLoadError(URLError(.timedOut))
        #expect(notices == [.offline])
    }
    #endif
}
