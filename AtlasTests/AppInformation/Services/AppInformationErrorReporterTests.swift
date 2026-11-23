//
//  AppInformationErrorReporterTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What App Information says when a read fails: Atlas's sentence first,
/// Apple's or the system's text only in Details.
@MainActor
@Suite("AppInformationErrorReporter")
struct AppInformationErrorReporterTests {
    private let push = PushController(queue: ChangeQueue(), history: PushHistory())

    @Test func applesErrorIsNeverTheMessage() {
        let message = AppInformationErrorReporter.report(AppStoreConnectError.server(statusCode: 503, detail: nil), to: push)
        #expect(message == "App information didn’t load. Apple didn’t answer. Try again in a minute.\nDetails: HTTP 503")
    }

    @Test func beingOfflineSaysWhatToDo() {
        let message = AppInformationErrorReporter.report(URLError(.notConnectedToInternet), to: push)
        #expect(push.notice == .offline)
        #expect(message.hasPrefix("App information didn’t load. Atlas can’t reach Apple. Check your connection and try again."))
    }

    @Test func theRequestLineKeepsTheSystemsCode() {
        let line = AppInformationErrorReporter.requestLine(for: CocoaError(.fileReadCorruptFile), request: "/v1/apps/1")
        #expect(line.hasSuffix("(NSCocoaErrorDomain \(CocoaError.Code.fileReadCorruptFile.rawValue)) · GET /v1/apps/1"))
    }
}
